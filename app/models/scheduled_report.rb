require "csv"

class ScheduledReport < BackgroundReport
  RECUR_INTERVALS = [
    ['Day', '1.day'],
    ['Week', '1.week'],
    ['Month', '1.month'],
    ['3 Months', '3.month']
  ].freeze

  REPORT_SPANS = %w{Days Weeks Months}.freeze
  REPORT_SPANS_VALUES = [1, 3].freeze

  before_save :adjust_parameters

  scope :not_completed, -> { where(completed: false) }

  validates_presence_of :report_type

  def is_outdated?
    account = Account.find_by_id(self.report_params[:account_id].to_i)
    return true if account.nil?

    if self.report_params[:device_id].to_i.positive?
      device = Device.find_by_id(self.report_params[:device_id])
      assigned = device.account_id == account.id
      return true if !device.active? || !assigned
    end

    false
  end

  def adjust_parameters
    self.report_span_value = 1 unless valid_monthly_state_mileage_report_span_value?
    self.report_span_units = 'Days' unless REPORT_SPANS.include?(self.report_span_units) # Don't ever eval user input w/o checking it first!
  end

  def filename
    self.report_name.downcase.gsub(/\s/, '_').gsub(/\W/, '') + '.csv'
  end

  def process(logger = Rails.logger)
    logger.info "#{Time.now.to_s(:db)} - REPORT ID: #{id} - PROCESSING"
    if scheduled_for.utc <= Time.now.utc + 5.minutes
      if is_outdated?
        destroy #rethink this !!!!!!!
        logger.info "#{Time.now.to_s(:db)} - REPORT ID: #{id} - OUTDATED"
      else
        begin
          logger.info "#{Time.now.to_s(:db)} - REPORT ID: #{id} - COMPUTING"
          complete && compute
          logger.info "#{Time.now.to_s(:db)} - REPORT ID: #{id} - COMPLETED"
        rescue Exception => e
          logger.info "#{Time.now.to_s(:db)} - REPORT ID: #{id} - INCOMPLETE"
          incomplete
          logger.info "#{Time.now.to_s(:db)} - #{e.message}"
        end
        if deliver_now
          logger.info "#{Time.now.to_s(:db)} - REPORT ID: #{id} - DELIVERED"
        end
      end
    end

    enqueue_scheduled_report unless self.completed?
  end

  def compute
    return true unless self.report_data.nil?

    results = self.report_data
    if REPORT_TYPES.include? self.report_type
      self.recompute
    end
  end

  def recompute
    self.update_attribute(:report_data, self.send(self.report_type))
  end

  def incomplete
    self.update_attributes({ report_data: nil, completed: false })
  end

  def complete
    return true if self.completed?
    self.update_attribute(:completed, true)

    if self.recur? && RECUR_INTERVALS.map(&:last).include?(recur_interval)
      next_iteration = self.class.new(self.attributes.reject { |k, v| ['created_at', 'updated_at', 'scheduled_for', 'completed', 'delivered_on', 'id', 'report_data'].include?(k) })
      next_iteration.scheduled_for = self.scheduled_for + eval(self.recur_interval)
      next_iteration.save
    end

    return true
  end

  def deliver_now
    return false if self.delivered_on
    return false unless self.report_data && self.completed?
    Notifier.scheduled_report(self).deliver_now
    self.update_attribute(:delivered_on, Time.now)
    true
  end

  def devices
    return @devices unless @devices.nil?

    return [] if self.report_params.blank?
    account = Account.find_by_id(self.report_params['account_id'].to_i)

    if account.nil?
      @devices = []
    elsif self.report_params['group_id'].blank? && self.report_params['device_id'].blank?
      @devices = account.provisioned_devices
    elsif self.report_params['device_id'].blank?
      group = account.groups.find_by_id(self.report_params['group_id'])
      @devices = group.nil? ? [] : group.devices
    else
      @devices = [Device.find_by_id(self.report_params['device_id'].to_i)].reject(&:nil?)
    end

    @devices
  end

  def state_mileage
    return '' unless self.user
    common_setup
    if from.nil? || to.nil?
      self.from = @start_date
      self.to   = @end_date
      self.save
    end

    target = ""

    csv_string = CSV.generate(force_quotes: true) do |csv|
      target = if report_params['group_id'] != ""
                 Group.find(report_params['group_id']).name
               elsif report_params['device_id'] != ""
                 Device.find(report_params['device_id']).name
               else
                 "All Fleets"
               end

      csv << ["Account:", user.account.company.to_s]
      csv << ["Report Name:", report_name.to_s]
      csv << ["Report Date:", Time.now.in_time_zone(time_zone).strftime(STANDARD_DATE_FORMAT).to_s]
      csv << ["Report Type:", report_type.titleize.to_s]
      csv << ["From Date:", from.in_time_zone(time_zone).strftime(STANDARD_DATE_FORMAT).to_s]
      csv << ["To Date:", (to - 1.second).in_time_zone(time_zone).strftime(STANDARD_DATE_FORMAT).to_s]
      csv << ["Applies To:", target]

      self.devices.each do |device|
        readings = device.readings.where(recorded_at: from..to)
        rg = readings.select { |r| r.location_id.nil? }
        rg.map(&:id).each_slice(500) { |rs| ReverseGeocoder.find_all_reading_addresses(rs) }
        readings.reload

        trip_legs = device.trip_legs.readonly.where('started_at between ? and ?', from, to)
        states = {}
        trip_legs.each_with_index do |leg, i|
          next if leg.reading_stop.latitude.nil? || leg.reading_start.latitude.nil?
          info = leg.calculate_mileage_and_duration_by_state
          states.merge!(info) { |key, v1, v2| v1.merge(v2) { |key, v1, v2| v1 += v2 } }
        end

        csv << []
        csv << ["Device:", device.name]
        csv << ["State", "Mileage", "Time"]

        total_duration = 0
        total_mileage  = 0
        states.each_key do |state|
          total_mileage += states[state][:mileage].round(1)
          total_duration += states[state][:duration]
          csv << [
            state,
            states[state][:mileage].round(1),
            seconds_to_time_output(states[state][:duration])
          ]
        end
        csv << ["Totals:", total_mileage.round(1), seconds_to_time_output(total_duration)]
      end
    end

    csv_string
  end

  def group_trip
    return '' unless self.user
    common_setup

    csv_string = CSV.generate(force_quotes: true) do |csv|
      csv << %W{Device On At Departed Travel\ Time Miles Arrived At Idle\ Time Stop\ Time}
      self.devices.each do |device|
        trip_legs = device.trip_legs.readonly.where('started_at between ? and ?', @start_dt_str, @end_dt_str)

        trip_legs.each_with_index do |leg, i|
          duration = if trip_legs[i + 1] && trip_legs[i + 1].reading_start && leg.reading_stop
                       standard_duration((trip_legs[i + 1].reading_start.recorded_at - leg.reading_stop.recorded_at) / 60)
                     else
                       ''
                     end

          csv << [
            device.name,
            leg.reading_start ? leg.reading_start.recorded_at.in_time_zone(self.time_zone).strftime(STANDARD_DATE_FORMAT) : '',
            leg.reading_start ? leg.reading_start.recorded_at.in_time_zone(self.time_zone).strftime(STANDARD_TIME_FORMAT) : '',
            leg.reading_start ? standard_location_text(device, leg.reading_start) : "",
            leg.duration ? standard_duration(leg.duration.to_f) : '',
            leg.distance ? sprintf('%2.1f', leg.distance) : '',
            leg.reading_stop ? standard_location_text(device, leg.reading_stop) : 'In Progress',
            leg.reading_stop ? leg.reading_stop.recorded_at.in_time_zone(self.time_zone).strftime(STANDARD_TIME_FORMAT) : '',
            leg.idle ? standard_duration(leg.idle / 60) : '',
            duration
          ]
        end
      end
    end

    csv_string
  end

  def stops
    return '' unless self.user
    common_setup
    csv_string = CSV.generate(force_quotes: true) do |csv|
      csv << %W{Device Location Stop\ Duration\ (minutes) Date Time}
      @stop_events = StopEvent.where('device_id IN (?)', self.devices.map(&:id)).not_suspect.between_dates(@start_dt_str, @end_dt_str).order('device_id ASC, started_at ASC')

      @stop_events.each do |stop|
        next if stop.reading.nil?
        csv << [
          stop.device.name,
          standard_location_text(stop.device, stop.reading),
          stop.duration.nil? ? 'In progress' : standard_duration(stop.duration / 60),
          stop.reading.recorded_at.in_time_zone.strftime(STANDARD_DATE_FORMAT),
          stop.reading.recorded_at.in_time_zone.strftime(STANDARD_TIME_FORMAT)
        ]
      end
    end

    csv_string
  end

  def sensors
    return '' unless self.user

    common_setup
    csv_string = CSV.generate(force_quotes: true) do |csv|
      csv << %W{Device Location Event\ Type Date\ Time}
      @sensor_readings = Reading.where('device_id IN (?)', self.devices.map(&:id))
                                .joins(:digital_sensor_reading)
                                .between_dates(@start_dt_str, @end_dt_str)
                                .order('device_id ASC, recorded_at ASC')

      @sensor_readings.each do |reading|
        csv << [
          reading.device.name,
          standard_location_text(reading.device, reading),
          reading.digital_sensor_reading.description,
          reading.recorded_at.in_time_zone.strftime(STANDARD_TIME_FORMAT)
        ]
      end
    end

    csv_string
  end

  def idle
    return '' unless self.user
    common_setup

    csv_string = CSV.generate(force_quotes: true) do |csv|
      csv << %W{Device Location Idle\ Duration\ (minutes) Date Time}

      @idle_events = IdleEvent.where('device_id IN (?)', self.devices.map(&:id)).not_suspect.between_dates(@start_dt_str, @end_dt_str).order('device_id ASC, started_at ASC')

      @idle_events.each do |idle|
        next if idle.reading.nil?
        csv << [
          idle.device.name,
          standard_location_text(idle.device, idle.reading),
          idle.duration.nil? ? 'In progress' : standard_duration(idle.duration / 60),
          idle.reading.recorded_at.in_time_zone.strftime(STANDARD_DATE_FORMAT),
          idle.reading.recorded_at.in_time_zone.strftime(STANDARD_TIME_FORMAT)
        ]
      end
    end

    csv_string
  end

  def maintenance
    return '' unless self.user
    common_setup

    csv_string = CSV.generate(force_quotes: true) do |csv|
      csv << ["Device", "Description", "Type", "Creation Date", "Target", "Actual", "Completion Date"]

      @maintenances = Maintenance.where(device_id: self.devices.map(&:id)).where(completed_at: @start_dt_str..@end_dt_str).order('device_id ASC, completed_at ASC')
      @maintenances.each do |maint|
        csv << [
          maint.device.name,
          maint.description_task,
          maint.type_string,
          standard_date(maint.created_at),
          maint.target_string,
          maint.actual_string,
          standard_date(maint.completed_at)
        ]
      end
    end

    csv_string
  end

  def speeding
    return '' if self.user.nil? || self.devices.empty?
    common_setup
    csv_string = CSV.generate(force_quotes: true) do |csv|
      csv << %W{Device Location Speed Event\ Type Date Time}
      readings = Reading.where('device_id IN (?)', self.devices.map(&:id)).between_dates(@start_dt_str, @end_dt_str).where(event_type: EventTypes::Speed).order('device_id ASC, recorded_at ASC')
      readings.each do |reading|
        csv << [
          reading.device.name,
          standard_location_text(reading.device, reading),
          reading.speed,
          reading.display_event_type,
          reading.recorded_at.in_time_zone.strftime(STANDARD_DATE_FORMAT),
          reading.recorded_at.in_time_zone.strftime(STANDARD_TIME_FORMAT)
        ]
      end
    end

    csv_string
  end

  def location
    return '' unless self.user
    common_setup

    csv_string = CSV.generate(force_quotes: true) do |csv|
      csv << %W{Device Location Speed Event\ Type Location Location\ Activity Date Time}
      readings = Reading.where('device_id IN (?)', self.devices.map(&:id)).between_dates(@start_dt_str, @end_dt_str).where('geofence_id != 0').where(geofence_event_type: %w(enter exit)).order('device_id ASC, recorded_at ASC')
      readings.each do |reading|
        csv << [
          reading.device.name,
          standard_location_text(reading.device, reading),
          reading.speed,
          reading.display_event_type,
          reading.geofence ? reading.geofence.name : 'Location',
          reading.geofence_event_type.titleize,
          reading.recorded_at.in_time_zone.strftime(STANDARD_DATE_FORMAT),
          reading.recorded_at.in_time_zone.strftime(STANDARD_TIME_FORMAT)
        ]
      end
    end

    csv_string
  end

  def common_setup
    time_zone = self.time_zone.blank? ? 'Central Time (US & Canada)' : self.time_zone

    Time.zone = time_zone

    self.report_span_units = 'Days' unless REPORT_SPANS.include?(self.report_span_units)

    @end_date = self.scheduled_for.in_time_zone.end_of_day - 1.day
    @end_dt_str = @end_date.utc.to_s(:db)

    @start_date = self.scheduled_for.in_time_zone.beginning_of_day - self.report_span_value.send(self.report_span_units.downcase)
    @start_dt_str = @start_date.utc.to_s(:db)
  end

  private

  def valid_monthly_state_mileage_report_span_value?
    REPORT_SPANS_VALUES.include?(self.report_span_value) && (self.report_type == 'state_mileage') && (self.report_span_units == 'Months')
  end

  def seconds_to_time_output(secs)
    return "" if secs.blank? || secs <= 0
    mm, ss = secs.divmod(60)
    hh, mm = mm.divmod(60)
    dd, hh = hh.divmod(24)
    return "#{dd} days, #{hh} hrs, #{mm} mins"
  end
end
