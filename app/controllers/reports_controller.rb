require 'csv'

class ReportsController < ApplicationController
  before_filter :authorize
  before_filter :authorize_device, except: ['index', 'trip_detail', 'leg_detail', 'export', 'scheduled_reports', 'all']
  helper_method :page_size
  helper_method :parse_url_date

  before_filter :authorize_super_admin, only: ['all_events']

  DAY_IN_SECONDS = 86400
  MAX_PAGESIZE = 1000 # Number of results per page
  MAX_LIMIT = 4096 # Max number of results
  SERVER_UTC_OFFSET = Time.now.utc_offset

  helper :maintenances
  include ApplicationHelper

  def mobile_supported?
    true
  end

  def page_size
    @page_size ||= MAX_PAGESIZE
  end

  def index
    # To allow groups to be selected on reports index page
    set_home_selection(params[:group_id]) if params[:group_id]
    @groups = current_account.groups.order('name')
    load_devices_filtered_by_chosen_group
  end

  def scheduled_reports
    @groups = current_account.groups.order('name')
    load_devices_filtered_by_chosen_group
    scheduled_reports = current_user.background_reports
    scheduled_reports = scheduled_reports.not_report_type('state_mileage') unless current_user.account.show_state_mileage_report?
    @scheduled_reports = scheduled_reports.reverse
  end

  def trip
    @page_size = 50
    @start_end_dates = true
    @device = Device.find(params[:id])
    @device_names = current_account.provisioned_devices
    get_start_and_end_date

    all_trip_legs = @device.trip_legs.not_suspect.readonly.includes(:reading_start, :reading_stop).where('started_at between ? and ? and reading_stop_id is not null', @start_dt_str, @end_dt_str)
    @trip_legs = all_trip_legs.paginate(per_page: @page_size, page: params[:page])
    @record_count = @trip_legs.total_entries
    @actual_record_count = @record_count
    @record_count = MAX_LIMIT if @record_count > MAX_LIMIT

    if @trip_legs && @trip_legs.size > 0
      @total_travel_time = all_trip_legs.sum(:duration)
      @total_idle_time = all_trip_legs.sum(:idle) / 60
      @total_distance = all_trip_legs.sum(:distance)
      @max_speed = all_trip_legs.collect(&:max_speed).compact.max
    else
      @total_travel_time =
      @total_idle_time =
      @total_distance =
      @max_speed = 0
    end

    # Enqueue readings for Reverse Geocoding
    @rg_readings = @trip_legs.collect(&:reading_start).concat(@trip_legs.collect(&:reading_stop)).compact
    enqueue_reading_ids_for_rg
  end

  def trip_detail
    @trip = TripEvent.find(params[:id])
    @device = @trip.device
    @device_names = current_account.provisioned_devices

    conditions = @trip.end_reading ? ['device_id = ? and recorded_at between ? and ?', @trip.device_id, @trip.start_reading.recorded_at, @trip.end_reading.recorded_at] : ['device_id = ? and recorded_at >= ?', @trip.device_id, @trip.end_reading.recorded_at]
    @readings = Reading.by_recorded_at('asc').where(conditions).paginate(per_page: page_size, page: params[:page])

    @record_count = @readings.total_entries
    @actual_record_count = @record_count
    @record_count = MAX_LIMIT if @record_count > MAX_LIMIT

    # Enqueue readings for Reverse Geocoding
    @rg_readings = @readings
    enqueue_reading_ids_for_rg
  end

  def leg_detail
    @leg = TripLeg.find_by(id: params[:id])

    if @leg
      @device = @leg.device
      @device_names = current_account.provisioned_devices

      conditions = @leg.reading_stop ? ['recorded_at between ? and ?', @leg.started_at, @leg.stopped_at] : ['recorded_at >= ?', @leg.started_at]
      @readings = @device.readings.by_recorded_at('asc').where(conditions).paginate(per_page: page_size, page: params[:page])

      @record_count = @readings.total_entries
      @actual_record_count = @record_count
      @record_count = MAX_LIMIT if @record_count > MAX_LIMIT
    else
      render nothing: true
    end

    # Enqueue readings for Reverse Geocoding
    @rg_readings = @readings
    enqueue_reading_ids_for_rg
  end

  def all
    # So end_date will default to start_date
    params[:end_date] = nil
    @device_names = current_account.provisioned_devices
    @device = params[:id].nil? ? @device_names.first : Device.find(params[:id])
    get_start_and_end_date
    @readings = @device.readings.by_recorded_at('desc').between_dates(@start_dt_str, @end_dt_str).paginate(per_page: page_size, page: params[:page])
    @record_count = @readings.total_entries
    @actual_record_count = @record_count
    @record_count = MAX_LIMIT if @record_count > MAX_LIMIT

    # Enqueue readings for Reverse Geocoding
    @rg_readings = @readings
    enqueue_reading_ids_for_rg
  end

  def maintenance
    @start_end_dates = true
    @device = Device.find(params[:id])
    @device_names = current_account.provisioned_devices
    get_start_and_end_date
    @maintenances = @device.maintenances.completed.where(completed_at: @start_dt_str..@end_dt_str).order('completed_at asc').paginate(per_page: page_size, page: params[:page])

    @record_count = @maintenances.total_entries
    @actual_record_count = @record_count
    @record_count = MAX_LIMIT if @record_count > MAX_LIMIT
  end

  def speeding
    # So end_date will default to start_date
    params[:end_date] = nil

    @device = Device.find(params[:id])
    @device_names = current_account.provisioned_devices
    get_start_and_end_date

    @readings = @device.readings.by_recorded_at('asc').between_dates(@start_dt_str, @end_dt_str).where("speed > :max_speed", max_speed: @device.max_speed || 60).paginate(per_page: page_size, page: params[:page])

    @record_count = @readings.total_entries
    @actual_record_count = @record_count
    @record_count = MAX_LIMIT if @record_count > MAX_LIMIT

    # Enqueue readings for Reverse Geocoding
    @rg_readings = @readings
    enqueue_reading_ids_for_rg
  end

  def stop
    # So end_date will default to start_date
    params[:end_date] = nil

    @device = Device.find(params[:id])
    @device_names = current_account.provisioned_devices
    get_start_and_end_date

    @stop_events = @device.stop_events.not_suspect.between_dates(@start_dt_str, @end_dt_str).by_started_at.paginate(per_page: page_size, page: params[:page])
    @stop_events.to_a.delete_if { |x| x.reading.nil? }

    @record_count = @stop_events.total_entries
    @actual_record_count = @record_count
    @record_count = MAX_LIMIT if @record_count > MAX_LIMIT

    # Enqueue readings for Reverse Geocoding
    @rg_readings = @stop_events.collect(&:start_reading).concat(@stop_events.collect(&:end_reading)).compact
    enqueue_reading_ids_for_rg
  end

  def idle
    # So end_date will default to start_date
    params[:end_date] = nil

    @device = Device.find(params[:id])
    @device_names = current_account.provisioned_devices
    get_start_and_end_date

    @idle_events = @device.idle_events.not_suspect.between_dates(@start_dt_str, @end_dt_str).by_started_at.paginate(per_page: page_size, page: params[:page])
    @idle_events.to_a.delete_if { |x| x.reading.nil? }

    @record_count = @idle_events.total_entries
    @actual_record_count = @record_count
    @record_count = MAX_LIMIT if @record_count > MAX_LIMIT

    # Enqueue readings for Reverse Geocoding
    @rg_readings = @idle_events.collect(&:start_reading).concat(@idle_events.collect(&:end_reading)).compact
    enqueue_reading_ids_for_rg
  end

  # Display geofence exceptions
  def geofence
    # So end_date will default to start_date
    params[:end_date] = nil
    @device = Device.find(params[:id])
    @device_names = current_account.provisioned_devices
    get_start_and_end_date
    # Geofences to display as overlays
    @geofences = @device.geofences
    @readings = @device.readings.by_recorded_at('asc').between_dates(@start_dt_str, @end_dt_str).where('geofence_id != 0').where(geofence_event_type: %w(enter exit)).paginate(per_page: RESULT_COUNT, page: params[:page])

    @record_count = @readings.total_entries
    @actual_record_count = @record_count
    @record_count = MAX_LIMIT if @record_count > MAX_LIMIT

    # Enqueue readings for Reverse Geocoding
    @rg_readings = @readings
    enqueue_reading_ids_for_rg
  rescue
    flash[:error] = $!.to_s
    redirect_to :back
  end

  def all_events
    @device = Device.find(params[:id])
    @device_names = current_account.provisioned_devices
    get_start_and_end_date

    @readings = Reading.find_by_sql(['SELECT readings.*, t1.id AS trip_start_id, (SELECT t2.id FROM trip_events t2 WHERE t2.end_reading_id = readings.id) AS trip_stop_id,
                                     t1.suspect AS trip_suspect,t1.duration AS trip_duration,i.id AS idle_id,i.duration,i.suspect AS idle_suspect,i.duration AS idle_duration,
                                     s.id AS stop_id,s.duration AS stop_duration,s.suspect AS stop_suspect
                                     FROM readings LEFT JOIN trip_events t1 ON readings.id = start_reading_id
                                     LEFT JOIN idle_events i ON i.start_reading_id = readings.id
                                     LEFT JOIN stop_events s ON s.start_reading_id = readings.id
                                     WHERE readings.device_id = ? AND readings.created_at >= ? AND readings.created_at <= ? ORDER BY readings.recorded_at, readings.id',
                                     params[:id], @start_dt_str, @end_dt_str])
    @record_count = @readings.size
    @actual_record_count = @record_count

    # Enqueue readings for Reverse Geocoding
    @rg_readings = @readings
    enqueue_reading_ids_for_rg
  rescue
    @rg_readings ||= []
    flash[:error] = $!.to_s
    @readings = []
    @record_count = 0
    @actual_record_count = 0
  end

  # Export report data to CSV
  def export
    params[:page] ||= 1
    if params[:type] == 'leg_detail'
      @leg = TripLeg.find_by(id: params[:id])
      @device = @leg.trip_event.device
    else
      @device = Device.find(params[:id])
    end
    get_start_and_end_date

    if params[:type] == 'stop'
      events = @device.stop_events.not_suspect.between_dates(@start_dt_str, @end_dt_str).by_started_at
    elsif params[:type] == 'idle'
      events = @device.idle_events.not_suspect.between_dates(@start_dt_str, @end_dt_str).by_started_at
    elsif params[:type] == 'trip'
      export_trip_legs and return
    elsif params[:type] == 'leg_detail'
      end_date = @leg.reading_stop ? @leg.reading_stop.recorded_at : Time.now

      readings = @device.readings.between_dates(@leg.reading_start.recorded_at, end_date).by_recorded_at('asc')
    elsif params[:type] == 'speeding'
      readings = @device.readings.by_recorded_at('asc').between_dates(@start_dt_str, @end_dt_str).where('speed > ?', @device.max_speed || 60)
    elsif params[:type] == 'geofence'
      readings = @device.readings.between_dates(@start_dt_str, @end_dt_str).where('geofence_id != 0').where(geofence_event_type: %w(enter exit)).by_recorded_at('desc')
    elsif params[:type] == 'maintenance'
      maintenances = @device.maintenances.completed.where(completed_at: @start_dt_str..@end_dt_str).order('completed_at asc')
    elsif params[:type] == 'digital_sensor'
      readings = @device.readings.joins(:digital_sensor_reading).by_recorded_at('asc').between_dates(@start_dt_str, @end_dt_str)
    else
      offset = (params[:page].to_i - 1) * RESULT_COUNT
      readings = @device.readings.between_dates(@start_dt_str, @end_dt_str).by_recorded_at('desc').limit(MAX_LIMIT).offset(offset)
    end

    @filename = "#{params[:type]}_for_#{@device.export_filename}.csv"
    csv_string = CSV.generate(force_quotes: true) do |csv|
      if params[:type] == 'maintenance'
        csv << ["Description", "Type", "Creation Date", "Target", "Actual", "Completion Date"]
        maintenances.each do |maint|
          csv << [maint.description_task, maint.type_string, standard_date(maint.created_at), maint.target_string, maint.actual_string, standard_date(maint.completed_at)]
        end
      elsif %w{stop idle trip}.include?(params[:type])
        csv << ['Address', "#{params[:type].capitalize} Duration (HH:MM)", 'Started', 'Latitude', 'Longitude']
        events.each do |event|
          local_time = event.started_at.in_time_zone.strftime(EMAIL_TIMESTAMP_FORMAT)
          address = event.reading.nil? ? "#{event.latitude};#{event.longitude}" : standard_location_text(@device, event.reading)
          csv << [address, ((event.duration.to_s.strip.size > 0) ? standard_duration(event.duration / 60) : 'Unknown'), local_time, event.latitude, event.longitude]
        end
      else
        csv << ['Address', 'Speed (mph)', 'Started', 'Latitude', 'Longitude', 'Event Type']
        readings.each do |reading|
          local_time = reading.recorded_at.in_time_zone.strftime(EMAIL_TIMESTAMP_FORMAT)
          csv << [standard_location_text(@device, reading), reading.speed, local_time, reading.latitude, reading.longitude, reading.show_event_type]
        end
      end
    end

    send_data csv_string,
      type: 'text/csv; charset=iso-8859-1; header=present',
      disposition: "attachment; filename=#{@filename}"
  end

  def digital_sensor
    params[:end_date] = nil

    @device = Device.find(params[:id])
    @device_names = current_account.devices_with_sensor_support
    get_start_and_end_date
    @readings = @device.readings.joins(:digital_sensor_reading).by_recorded_at('asc').between_dates(@start_dt_str, @end_dt_str).paginate(per_page: page_size, page: params[:page])
    @record_count = @readings.total_entries
    @actual_record_count = @record_count
    @record_count = MAX_LIMIT if @record_count > MAX_LIMIT

    @rg_readings = @readings
    enqueue_reading_ids_for_rg
  end

  def parse_url_date(date_fields)
    return if date_fields.nil?
    return date_fields if date_fields.is_a? String
    Date.parse [date_fields["year"], date_fields["month"], date_fields["day"]].join('-') rescue nil
  end

  private

  def get_start_and_end_date
    begin
      params[:time_frame] ||= {}
      if params['start_date'] and params['start_date'] != ''
        if params['start_date'].class.to_s == 'String'
          @end_date = @start_date = params['start_date'].to_date
        else
          @end_date = @start_date = get_date(params['start_date']).to_date
        end
      else
        @from_normal = true  #TODO:  is this line deprecated?  where would this be used?
        @end_date = @start_date = Time.now.in_time_zone.to_date
      end

      if params['end_date'] and params['end_date'] != ''
        if params['end_date'].class.to_s == 'String'
          @end_date = params['end_date'].to_date
          @start_date = params['start_date'].to_date
        else
          @end_date = get_date(params['end_date'])
          @start_date = get_date(params['start_date'])
        end
      end
      unless params['start_date'] || params['end_date'] || @device.nil?
        date = @device.date_of_last_reading
        if date
          @start_date = @end_date = get_date({ "month"=> date.month.to_s, "day"=> date.day.to_s, "year"=> date.year.to_s })
        end
      end
    rescue ArgumentError
      flash.now[:error] = 'Invalid date'
      @end_date = @start_date = Time.now.in_time_zone.to_date
    end

    @start_date, @end_date = @end_date, @start_date if @end_date < @start_date

    if params[:time_frame][:set_time_frame] == "1"
      hour = params[:time_frame]["start_time(4i)"].to_i
      min = params[:time_frame]["start_time(5i)"].to_i
      dur = params[:time_frame][:time_duration].to_i

      @start_date_time = @start_date.beginning_of_day.in_time_zone.change(hour: hour, min: min)

      @start_dt_str = (@start_date_time).to_s(:db)
      @end_dt_str   = (dur.hours.from_now(@start_date_time)).to_s(:db)
    else
      @start_dt_str = (@start_date.beginning_of_day.in_time_zone).to_s(:db)
      @end_dt_str   = (@end_date.end_of_day.in_time_zone).to_s(:db)
    end
  end

  def export_trip_legs
    @device = Device.find(params[:id])
    trip_legs = @device.trip_legs.not_suspect.readonly.includes(:reading_start, :reading_stop).where('started_at between ? and ? and reading_stop_id is not null', @start_dt_str, @end_dt_str)

    csv_string = CSV.generate(force_quotes: true) do |csv|
      csv << %W{On At Departed Travel\ Time Miles Arrived At Idle\ Time Stop\ Time}
      trip_legs.each_with_index do |leg, i|
        if next_leg = trip_legs[i + 1]
          next_leg_start = next_leg.reading_start.try(:recorded_at)
        else
          next_leg_start = leg.reading_stop.try(:recorded_at)
        end
        stop_duration = leg.stop_duration(next_leg_start)

        csv << [
          leg.reading_start ? leg.reading_start.recorded_at.in_time_zone.strftime(STANDARD_DATE_FORMAT) : '',
          leg.reading_start ? leg.reading_start.recorded_at.in_time_zone.strftime(STANDARD_TIME_FORMAT) : '',
          leg.reading_start ? standard_location_text(leg.trip_event.device, leg.reading_start) : '',
          leg.duration ? standard_duration(leg.duration.to_f) : '',
          leg.distance ? sprintf('%2.1f', leg.distance) : '',
          leg.reading_stop ? standard_location_text(leg.trip_event.device, leg.reading_stop) : 'In Progress',
          leg.reading_stop ? standard_time(leg.reading_stop.recorded_at) : '',
          leg.idle ? standard_duration(leg.idle / 60) : '',
          stop_duration ? standard_duration(stop_duration) : 'In Progress'
        ]
      end
    end

    send_data csv_string,
      type: 'text/csv; charset=iso-8859-1; header=present',
      disposition: "attachment; filename=trips_for_#{@device.export_filename}.csv"
  end

  def get_date(date_inputs)
    Date.parse [date_inputs["year"], date_inputs["month"], date_inputs["day"]].join('-')
  end
end
