require 'net/http'
require "rexml/document"

class Reading < ActiveRecord::Base
  include ApplicationHelper
  include TelematicsSupport
  include Geokit::ActsAsMappable

  has_one :digital_sensor_reading

  GEOFENCE_TYPE_NORMAL = 'normal'.freeze
  GEOFENCE_TYPE_ENTER  = 'enter'.freeze
  GEOFENCE_TYPE_EXIT   = 'exit'.freeze

  MAX_NEARBY_RADIUS = 0.25
  EMAIL_NOTIFICATION_METHODS = [
    :geofence_notifications,
    :non_working_hours_movement_notifications,
    :startup_notifications,
    :first_movement_notifications,
    # :gpio_notifications, @todo This isn't defined, what should we do here?
    :speed_notifications,
    :movement_alerts,
    :gps_unit_power_notifications
  ].freeze

  GATEWAY_EVENT_TYPES_THAT_SHOULD_SHOW_UP_AS_NORMAL = %w{
    idling obd_unplugged accelerometer_calibrated gps_on gps_off gps_reset gps_lost towing_in_tow
    towing_cleared towing panic_alert speeding speeding_cleared rpms
    rpms_cleared idling idling_cleared malfunction_indicator_light turning_left
    turning_right turning_left_cleared turning_right_cleared turning_right_clear accelerating
    accelerating_cleared decelerating decelerating_cleared main_power_low_cleared low_fuel_cleared
    gps_acquired}

  ALL_EVENT_TYPE_IDS = EventTypes.all.collect(&:id)
  EVENT_TYPE_MSG = { EventTypes::Panic          => 'Panic',
                     EventTypes::EngineOff      => 'Engine Off',
                     EventTypes::EngineOn       => 'Engine On',
                     EventTypes::Speed          => 'Speed',
                     EventTypes::Idling         => 'Idling',
                     EventTypes::PlugIn         => 'Plug In',
                     EventTypes::NoGPS          => 'No GPS',
                     EventTypes::Requested      => 'Requested',
                     EventTypes::LowBattery     => 'Low Battery',
                     EventTypes::Heartbeat      => 'Heartbeat',
                     EventTypes::Ignition       => 'Ignition',
                     EventTypes::Maintenance    => 'Maintenance',
                     EventTypes::StartMotion    => 'Start Motion',
                     EventTypes::StopMotion     => 'Stop Motion',
                     EventTypes::CutWire        => 'Cut Wire',
                     EventTypes::DiagnosticData => 'Diagnostic Data',
                     EventTypes::PowerUp        => 'Power Up',
                     EventTypes::MotionAlarm    => 'Motion Alarm',
                     EventTypes::Tamper         => 'Tamper',
                     EventTypes::TemperatureAlarm    => 'Temp Alarm',
                     EventTypes::TemperatureAlarmCleared    => 'Temp Alarm Clear',
  }
  acts_as_mappable  lat_column_name: :latitude, lng_column_name: :longitude

  belongs_to :device
  belongs_to :geofence
  belongs_to :location
  has_one :account, through: :device
  has_one :stop_event
  has_one :group, through: :device
  has_one :digital_sensor_reading

  self.primary_key = :id

  scope :with_gps, -> { not_null(:latitude).not_null(:longitude) }
  scope :not_null, lambda { |attribute| where(self.arel_table[attribute].not_eq(nil)) }
  scope :after_date, lambda { |date| where('readings.recorded_at >= ? ', date) }
  scope :by_recorded_at, lambda { |direc| reorder(direc == 'asc' ? 'recorded_at asc' : 'recorded_at desc') }
  scope :between_dates, lambda { |start_dt, end_dt| where(recorded_at: start_dt..end_dt) }
  scope :for_date_range, lambda { |start_date, end_date| where('readings.recorded_at >= ? AND readings.recorded_at <= ?', start_date, end_date) }
  scope :for_date_strict_range, lambda { |start_date, end_date| where('readings.recorded_at > ? AND readings.recorded_at < ?', start_date, end_date) }
  scope :by_ids_with_location, ->(ids) { where(id: ids).where("location_id IS NOT NULL").includes(:location) }

  delegate :phone_number, to: :device, prefix: true, allow_nil: true
  delegate :name, to: :device, prefix: true

  def self.create_from_message(event_state, server_time, message)
    device  = event_state.device
    reading = Reading.new
    reading.device = device # HACK - required to prevent SQL select

    reading.data = message
    reading.gateway_event_type = calamp_gateway_event_type(message['evt'])
    reading.received_at = server_time
    return unless validate_message_time(message, reading)

    valid_gps = validate_gps(message['gps'], reading)

    reading.save!

    device.last_online_time = server_time
    device.last_reading = reading
    device.last_gps_reading = reading if valid_gps
    device.last_speed_reading = reading if reading.speed
    device.set_battery_level_from_reading(reading)

    exception_guard { event_state.consider_transition }

    exception_guard do
      reading.consider_gateway_event_type
      reading.refresh_status_and_process_email_notification
    end

    device.last_ignition_state = reading.ignition if device.last_ignition_state.nil? or (not reading.ignition.nil? and reading.ignition != device.last_ignition_state)

    device.save!(validate: false)
    device.update_mileage!
  end

  def set_location(location)
    update_attributes(location_id: location.to_param)
    device.update_attributes(last_rg_reading_id: self.id) if location
  end

  # Sets the event type if the attribute value is nil
  def set_event_type(new_event_type, save_bang = false)
    return unless self.event_type.nil?

    self.event_type = new_event_type
    save! if save_bang
    new_event_type
  end

  def event_type_str
    if event_type.nil?
      fence_description unless geofence_event_type.blank?
    elsif EVENT_TYPE_MSG.keys.include?(event_type)
      EVENT_TYPE_MSG[event_type]
    end
  end

  def altitude
    self.data['altitude']
  end

  def gpio1
    self.data['gpio1']
  end

  def gpio1=(gpio1)
    self.data['gpio1'] = gpio1
  end

  def note
    self.data['note']
  end

  def ignition
    if device.properties.suspect_ignition
      case gateway_event_type
        when *%w(ignition_on ignition_transition_on idling) then true
        when *%w(ignition_off ignition_transition_off)      then false
        else
          case (self.data['io'] || {})['din4']
            when 1 then true
            when 0 then false
            else        nil
          end
      end
    else
      case (self.data['eng'] || {})['ign']
        when 1 then true
        when 0 then false
        else        nil
      end
    end
  rescue
    nil
  end

  def in_motion?
    return in_motion if(device.supports_motion?)

    return nil if(!device.supports_speed? or speed.nil?)
    speed > 0
  end

  def formatted_speed user
    if user.measure_units == ConversionUtils::MEASURE_UNITS[ConversionUtils::KPH_VALUE].value
      (self.speed * ConversionUtils::CONVERT_MPH_TO_KPH).round unless self.speed.nil?
    else
      self.speed.round unless self.speed.nil?
    end
  end

  def exceeds_speed_threshold?(speed_threshold = 0)
    return unless speed_threshold && speed
    speed > speed_threshold
  end

  def battery_low?
    (device.supports_battery_level? || device.compute_battery_usage?) && battery_voltage && device.battery_level_threshold && battery_voltage < device.battery_level_threshold
  end

  def internal_battery_low?
    return false unless device.supports_internal_battery? || device.compute_battery_usage?

    return nil if device.internal_battery_level_threshold.nil?
    internal_battery_voltage < device.internal_battery_level_threshold
  end

  def in_motion
    self.data['in_motion']
  end

  def in_motion=(in_motion)
    self.data['in_motion'] = in_motion
  end

  def gpio2
    self.data['gpio2']
  end

  def gpio2=(gpio2)
    self.data['gpio2'] = gpio2
  end

  def has_gps?
    !latitude.blank? && !longitude.blank?
  end

  def geofence_exit?
    geofence_event_type == GEOFENCE_TYPE_EXIT
  end

  def geofence_enter?
    geofence_event_type == GEOFENCE_TYPE_ENTER
  end

  def geofence_normal?
    geofence_event_type == GEOFENCE_TYPE_NORMAL
  end

  def set_ignition_event_type
    return unless device.supports_telematics?

    set_event_type_on_transition(:ignition, EventTypes::EngineOn, EventTypes::EngineOff)
  end

  def set_event_type_on_transition(field_name, rising_event_type, falling_event_type)
    if device.status_changed?(self, field_name)
      new_event_type = (self.send(field_name) ? rising_event_type : falling_event_type)
      set_event_type(new_event_type)
    end
  end

  def set_battery_voltage(external_voltage, internal_voltage)
    self.internal_battery_voltage = internal_voltage if device.supports_internal_battery?

    self.battery_voltage = device.supports_all_battery_types? ? external_voltage : external_voltage || internal_voltage
  end

  def short_address
    location ? location.format_address : "#{latitude}, #{longitude}"
  end

  def display_speed
    self.speed.nil? ? "N/A" : self.speed.round
  end

  def self.generate_direction_string(dir)
    if dir.nil?
      return 'n/a'
    elsif dir >= 337.5 or dir < 22.5
      return "n"
    elsif dir >= 22.5 and dir < 67.5
      return "ne"
    elsif dir >= 67.5 and dir < 112.5
      return "e"
    elsif dir >= 112.5 and dir < 157.5
      return "se"
    elsif dir >= 157.5 and dir < 202.5
      return "s"
    elsif dir >= 202.5 and dir < 247.5
      return "sw"
    elsif dir >= 247.5 and dir < 292.5
      return "w"
    elsif dir >= 292.5 and dir < 337.5
      return "nw"
    end
  end

  def direction_string
    self.class.generate_direction_string(direction).upcase
  end

  def ignition=(value) # NOTE - this should only be used for testing!!
    self.data ||= {}
    self.data['eng'] ||= {}
    case value
      when true  then self.data['eng']['ign'] = 1
      when false then self.data['eng']['ign'] = 0
      else            self.data['eng']['ign'] = nil
    end
  end

  def direction
    self.data['gps']['head'].to_f rescue nil
  end

  def power_up?
    self.data['power_up']
  end

  def get_fence_name
    return nil if self.geofence_id.zero? || self.geofence_id.blank?
    @fence_name ||= self.geofence.nil? ? nil : self.geofence.name
  end

  def fence_description
    return '' if self.geofence_id.to_i.zero?
    @fence_description ||= (['enter', 'exit'].include?(self.geofence_event_type) ? "#{self.geofence_event_type}ing " : 'within ') + (get_fence_name() || 'location')
  end

  def apply_geofences(logger = nil)
    return nil unless self.device and self.device.consider_geofence_reading?(self)

    start_time = Time.now

    account_id = self.device.account_id

    previously_violated_geofence_ids = GeofenceViolation.where(device_id: self.device_id)
                                                        .order('violation_time DESC')
                                                        .pluck(:geofence_id).to_a

    relevant_geofence_ids = Geofence.not_null(:latitude).not_null(:longitude).where(account_id: account_id)
                                    .where('device_id = ? OR (device_id=0 or device_id is NULL)', self.device_id).order('area ASC')

    currently_violated_geofence_ids = relevant_geofence_ids.select { |g| self.distance_to(g) <= g.radius }
    currently_violated_geofence_ids.delete_if { |x| x.polygonal? && !x.encloses?(self) }
    currently_violated_geofence_ids.collect!(&:id)

    newly_entered_geofences = (currently_violated_geofence_ids - previously_violated_geofence_ids)
    newly_exited_geofences = (previously_violated_geofence_ids - currently_violated_geofence_ids)

    #Most important event is enter, followed by exit, followed by a "normal"
    if !newly_entered_geofences.empty?
      self.update_attributes(geofence_id: newly_entered_geofences.first, geofence_event_type: GEOFENCE_TYPE_ENTER)
      GeofenceViolation.create(device_id: self.device_id, geofence_id: newly_entered_geofences.first, violation_time: Time.now)
      geofence_event = :enter
      geofence_id = newly_entered_geofences.first
    elsif !newly_exited_geofences.empty?
      self.update_attributes(geofence_id: newly_exited_geofences.first, geofence_event_type: GEOFENCE_TYPE_EXIT)
      GeofenceViolation.delete_all(device_id: self.device_id, geofence_id: newly_exited_geofences.first)
      geofence_event = :exit
      geofence_id = newly_exited_geofences.first
    elsif !currently_violated_geofence_ids.empty?
      self.update_attributes(geofence_id: currently_violated_geofence_ids.first, geofence_event_type: GEOFENCE_TYPE_NORMAL) # TODO this is probably wrong now...
      geofence_event = :normal
      geofence_id = nil
    else
      #these are SQL defaults, and this statement will only execute if these columns have been _changed_
      self.update_attributes(geofence_id: nil, geofence_event_type: nil)
      geofence_event = nil
      geofence_id = nil
    end
    logger.info "Reading #{self.id}, apply_geofences took #{(Time.now - start_time).to_f.round(4)} seconds" if logger
    return geofence_event, geofence_id
  end

  def refresh_status_and_process_email_notification(logger = nil)
    EMAIL_NOTIFICATION_METHODS.each do |notification_type|
      t1 = Time.now
      self.send(notification_type)
      t2 = Time.now

      logger.info("Reading #{self.id}, #{notification_type} took #{(t2 - t1).to_f.round(4)} seconds") if logger
    end
  end

  def geofence_notifications
    apply_geofences

    return unless recorded_at && (geofence_enter? || geofence_exit?) &&
       device && !device.deleted? && geofence && geofence.notify_enter_exit?

    action = geofence_exit? ? 'exited geofence ' : 'entered geofence '

    action += get_fence_name unless get_fence_name.nil?
    action += ' at ' + self.force_location
    Notifier.send_notify_reading_to_users(action, self, :geofence)
  end

  def movement_alerts
    alerts_delivered = 0
    alerts = device.movement_alerts.open_alerts

    return unless alerts.any?

    alerts.each do |alert|
      if alert.is_violated_by(self)
        begin
          alert.mark_as_closed(self)

          t1 = Time.now
          alert.deliver_now
          logger.info("notifying about movement alert #{alert.id} for device #{alert.device_id}... took #{(Time.now - t1).round(3)}s") if logger

          alerts_delivered += 1
        rescue ActiveRecord::RecordNotUnique
          logger.info "Could not close alert because an identical alert already existed" if logger
        end
      end
    end

    logger.info("#{alerts_delivered} Movement Alerts have been triggered") unless logger.nil? || alerts_delivered.zero?
  end

  def with_max_speed
    group && group.max_speed && group.max_speed > 0 || account && account.max_speed && account.max_speed > 0
  end

  def speed_notifications
    return unless speed.present? && device.active? && self.with_max_speed

    if device.speeding_at && self.speed == 0
      device.update_attribute(:speeding_at, nil)
    elsif device.speeding_at.nil? && self.speed > device.max_speed
      device.update_attribute(:speeding_at, self.recorded_at)
      set_event_type(EventTypes::Speed, true)
      Notifier.send_notify_reading_to_users("maximum speed of #{device.max_speed} MPH exceeded", self, :speed)
    end
  end

  def first_movement_notifications
    return unless device && device.notify_on_first_movement? && (device.most_recent_first_movement.nil? || device.most_recent_first_movement < DateTime.now.in_time_zone(account.try :time_zone).beginning_of_day)

    if speed && speed > 0 && recorded_at > DateTime.now.in_time_zone(account.try :time_zone).beginning_of_day
      device.update_attribute(:most_recent_first_movement, self.recorded_at)
      Notifier.send_notify_reading_to_users("First movement for device \"#{device.name}\"", self, :first_movement)
    end
  end

  def startup_notifications
    Notifier.send_notify_reading_to_users('was powered up', self, :startup) if power_up?
  end

  def non_working_hours_movement_notifications
    return unless device.try(:notify_on_working_hours?)

    if account.outside_working_hours? recorded_at
      if speed.to_i > 0 && !device.has_notified_working_hours_violation?
        Notifier.send_notify_reading_to_users('reported movement outside of working hours', self, :non_working)
        device.update_attribute(:has_notified_working_hours_violation, true)
      end
    else
      if device.has_notified_working_hours_violation?
        device.update_attribute(:has_notified_working_hours_violation, false)
      end
    end
  end

  def gps_unit_power_notifications
    if ['main_power_disconnected_cleared', 'main_power_disconnected'].include?(gateway_event_type) and device and device.notify_on_gps_unit_power_events?
      Notifier.send_notify_reading_to_users(show_event_type, self, :gps_unit_power)
    end
  end

  def destroy_if_undesirable_gateway_event_type(logger = nil)
    # Commented for now-  apparently we are NOT deleting any readings.  But maybe we'll change our mind.  -ctk
    #    if GATEWAY_EVENT_TYPES_THAT_SHOULD_TRIGGER_DESTRUCTION.include?(self.gateway_event_type)
    #      logger.warn "#{Time.now.to_s(:db)} - destroying reading #{self.id} for device #{self.device_id} because it has gateway_event_type #{self.gateway_event_type}" if logger
    #      self.destroy
    #      return true
    #    end
    return false
  end

  def consider_gateway_event_type
    return if event_type

    case result = gateway_event_type.to_s.downcase
      when 'startstop_et41'
        set_event_type(EventTypes::Stop, true)
      when 'speed alert', 'speeding'
        set_event_type(EventTypes::Speed, true)
      when 'virtual ignition on'
        self.update_attributes(gateway_event_type: 'Ignition On')
      when 'virtual ignition off'
        self.update_attributes(gateway_event_type: 'Ignition Off')
      when 'ignition on event', 'virtual ignition on event'
        set_event_type(EventTypes::EngineOn, true)
      when 'ignition off event', 'virtual ignition off event'
        set_event_type(EventTypes::EngineOff, true)
      when 'aux input high'
        self.update_attributes(gpio1: true)
      when 'aux input low'
        self.update_attributes(gpio1: false)
      else
        consider_binary_reading(result)
    end
  end

  def consider_binary_reading(event_type)
    if (matches = event_type.match(/input_(low|high)_(\d+)/))
      input_address = matches[2].to_i
      input_value = (matches[1] == 'high')
    elsif event_type == 'sensor_changed'
      if payload_data['digital_input_01'].present?
        input_address, input_value  = 1, payload_data['digital_input_01'] == '1'
      elsif payload_data['digital_input_02'].present?
        input_address, input_value = 2, payload_data['digital_input_02'] == '1'
      end
    end

    create_binary_sensor_reading(input_address, input_value) if input_address
  end

  def show_event_type
    displayable_value = case event_type
                          when EventTypes::Speed, EventTypes::Idling, EventTypes::EngineOn, EventTypes::EngineOff
                            event_type_str
                          when EventTypes::Stop
                            'Stop'
                          when EventTypes::AssetHighToLow, EventTypes::AssetLowToHigh
                            digital_sensor_reading.description
                        end

    #all of these values came from "Master Device Event codes.xslx" made by
    #Jason Maravich.  The wording or logic might seem odd, but it simply
    #is what the customer demands.  I've decided to let him change his mind
    #later if he doesn't like it because I haven't been able to convince them
    #of anything else.  -ctk
    displayable_value ||= 'Normal' if GATEWAY_EVENT_TYPES_THAT_SHOULD_SHOW_UP_AS_NORMAL.include?(gateway_event_type)
    displayable_value ||= case gateway_event_type
                            when 'motion_cleared'
                              'Stop Motion'
                            when 'ignition_distance'
                              'Engine On Distance'
                            when 'located'
                              'Requested Location'
                            when 'main_power_disconnected_cleared'
                              'GPS Unit Connected'
                            when "main_power_disconnected"
                              'GPS Unit Disconnected'
                            when 'backup_power_low'
                              'GPS Unit Battery Low'
                            when 'obd_plugged_in'
                              'OBD Detected'
                            when 'fota'
                              'FOTA'
                            when "ignition_transition_on"
                              'Engine On'
                            when "ignition_transition_off"
                              'Engine Off'
                            when "cellular_modem_off"
                              'GSM Modem Off'
                            when "cellular_modem_on"
                              'GSM Modem On'
                            when 'main_power_low'
                              'Vehicle Battery Low'
                            when 'motion'
                              'Start Motion'
                            when 'no_motion'
                              'Stopped'
                            when 'power_on'
                              'GPS Unit Connected'
                            when 'event_normal'
                              'Asset Stopped'
                            when 'event_motion'
                              'Asset Start Motion'
                            when 'event_moving'
                              'Asset Moving'
                            when 'event_stopped'
                              'Asset Stop Motion'
                            when 'event_backup_power_low'
                              'Asset GPS Unit Battery Low'
                            else
                              gateway_event_type.to_s.titleize
                        end

    displayable_value
  end

  def create_binary_sensor_reading(sensor_address, input_value)
    Device.transaction do
      self.event_type = (input_value ? EventTypes::AssetLowToHigh : EventTypes::AssetHighToLow)

      digital_sensor = device.sensor(sensor_address)
      if digital_sensor.new_record?
        digital_sensor.device = self.device
        digital_sensor.save!
      end

      digital_sensor.create_new_digital_sensor_reading(self, input_value)
      self.save!
    end
  end

  def force_location
    ReverseGeocoder.find_address_for_reading(self) unless self.location
    (self.location && self.location.format_address) || self.short_address
  end

  def display_event_type
    gateway_event_type == 'Deaccelleration Alert' ? 'Hard Braking' : show_event_type
  end

  def valid_lat_and_lng?
    !self.latitude.nil? && !self.longitude.nil?
  end

end
