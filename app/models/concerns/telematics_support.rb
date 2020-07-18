module TelematicsSupport
  extend ActiveSupport::Concern

  TOO_OLD_DISCARD_SECONDS = 21 * 24 * 60 * 60 # 3 weeks in the past
  TOO_NEW_DISCARD_SECONDS = -5 * 60           # 5 minutes in the future
  REQUIRED_HDOP           = 5.0
  EARTH_RADIUS_MILES      = 3956

  PRIMARY_DATE_FORMAT = '%Y-%m-%dT%H:%M:%S.%L%Z'.freeze
  SECONDARY_DATE_FORMAT = '%Y-%m-%dT%H:%M:%S%z'.freeze

  LOCATED = 'located'.freeze
  IGNITION_TRANSITION_ON = 'ignition_transition_on'.freeze
  SPEEDING = 'speeding'.freeze
  HEARTBEAT = 'heartbeat'.freeze

  GEOFENCE_ENTRY_00 = 'geofence_entry_00'.freeze
  GEOFENCE_ENTRY_01 = 'geofence_entry_01'.freeze
  GEOFENCE_ENTRY_02 = 'geofence_entry_02'.freeze
  GEOFENCE_ENTRY_03 = 'geofence_entry_03'.freeze
  GEOFENCE_ENTRY_04 = 'geofence_entry_04'.freeze

  GEOFENCE_EXIT_00 = 'geofence_exit_00'.freeze
  GEOFENCE_EXIT_01 = 'geofence_exit_01'.freeze
  GEOFENCE_EXIT_02 = 'geofence_exit_02'.freeze
  GEOFENCE_EXIT_03 = 'geofence_exit_03'.freeze
  GEOFENCE_EXIT_05 = 'geofence_exit_05'.freeze

  IGNITION_TRANSITION_OFF = 'ignition_transition_off'.freeze
  GPS_ACQUIRED = 'gps_acquired'.freeze
  GPS_LOST = 'gps_lost'.freeze
  POWER_ON = 'power_on'.freeze
  MOTION = 'motion'.freeze
  MOVING = 'moving'.freeze
  MOTION_CLEARED = 'motion_cleared'.freeze
  STOPPED = 'stopped'.freeze
  IDLING = 'idling'.freeze
  IGNITION_ON = 'ignition_on'.freeze
  IGNITION_OFF = 'ignition_off'.freeze
  IGNITION_DISTANCE = 'ignition_distance'.freeze
  TOWING = 'towing'.freeze
  MAIN_POWER_LOW = 'main_power_low'.freeze
  BACKUP_POWER_LOW = 'backup_power_low'.freeze
  MAIN_POWER_DISCONNECTED_CLEARED = 'main_power_disconnected_cleared'.freeze
  MAIN_POWER_DISCONNECTED = 'main_power_disconnected'.freeze

  INPUT_HIGH_04 = 'input_high_04'.freeze
  INPUT_HIGH_03 = 'input_high_03'.freeze
  INPUT_HIGH_02 = 'input_high_02'.freeze
  INPUT_HIGH_01 = 'input_high_01'.freeze
  OUTPUT_HIGH_01 = 'output_high_01'.freeze
  OUTPUT_HIGH_02 = 'output_high_02'.freeze

  INPUT_LOW_04 = 'input_low_04'.freeze
  INPUT_LOW_03 = 'input_low_03'.freeze
  INPUT_LOW_02 = 'input_low_02'.freeze
  INPUT_LOW_01 = 'input_low_01'.freeze
  OUTPUT_LOW_01 = 'output_low_01'.freeze

  module ClassMethods

    def validate_gps(gps_data,reading)
      return false if not gps_data or gps_data['hdop'].to_f > REQUIRED_HDOP

      latitude = gps_data['lat']
      longitude = gps_data['lng']
      if (valid_gps = latitude && longitude && !(latitude.to_f == 0 && longitude.to_f == 0))
        reading.latitude  = latitude
        reading.longitude = longitude
        reading.speed = ConversionUtils.km_to_miles(gps_data['speed'].to_f).round rescue nil
      else
        reading.set_event_type(EventTypes::NoGPS)
      end

      valid_gps
    end

    def validate_message_time(message,reading)
      if message['tmrpt'].blank?
        log_skipped_reading('it has no event timestamp')
      else
        message_time = message['tmrpt']
        reading.recorded_at = parse_time(message_time) || reading.received_at

        recorded_received_time_gap = reading.received_at - reading.recorded_at
        log_skipped_reading("it is too old: #{message_time}") unless (valid_min_date = recorded_received_time_gap <= TOO_OLD_DISCARD_SECONDS)
        log_skipped_reading("it is too new: #{message_time}") unless (valid_max_date = recorded_received_time_gap >= TOO_NEW_DISCARD_SECONDS)
      end

      valid_min_date && valid_max_date
    end

    def parse_time(string_time)
      DateTime.strptime(string_time, PRIMARY_DATE_FORMAT).utc if string_time

    rescue ArgumentError
      begin
        DateTime.strptime(string_time, SECONDARY_DATE_FORMAT).utc
      rescue ArgumentError
        nil
      end
    end

    def distance_between_readings(*readings)
      readings = Array(readings[0]) if readings.length == 1
      distance,previous_reading = 0,nil
      readings.each do |next_reading|
        distance += distance_between_two_lat_lng(previous_reading.latitude,previous_reading.longitude,next_reading.latitude,next_reading.longitude) if previous_reading and next_reading
        previous_reading = next_reading
      end
      distance
    end

    #Returns in miles the distance between two given coordinates using the haversine formula of distance
    def distance_between_two_lat_lng(lat1, lon1, lat2, lon2)
      unless (lat1.blank? || lat2.blank? || lon1.blank? || lon2.blank?)
        dlon = lon2 - lon1
        dlat = lat2 - lat1

        dlon_rad = dlon * (Math::PI/180)
        dlat_rad = dlat * (Math::PI/180)

        lat1_rad = lat1 * (Math::PI/180)
        lat2_rad = lat2 * (Math::PI/180)

        a = (Math.sin(dlat_rad/2))**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * (Math.sin(dlon_rad/2))**2
        c = 2 * Math.atan2( Math.sqrt(a), Math.sqrt(1-a))
        return EARTH_RADIUS_MILES * c          # delta between the two points in miles
      else
        0
      end
    end

    def calamp_gateway_event_type(event_code)
      case event_code
        when nil then nil
        when String then event_code

        when 1 then LOCATED
        when 3 then IGNITION_TRANSITION_ON
        when 4 then SPEEDING
        when 5 then HEARTBEAT

        when 6 then GEOFENCE_ENTRY_00
        when 7 then GEOFENCE_EXIT_00
        when 8 then GEOFENCE_ENTRY_01
        when 9 then GEOFENCE_EXIT_01

        when 10 then GEOFENCE_ENTRY_02
        when 11 then GEOFENCE_EXIT_02
        when 12 then GEOFENCE_ENTRY_03
        when 13 then GEOFENCE_EXIT_03
        when 14 then GEOFENCE_ENTRY_04

        when 15 then IGNITION_TRANSITION_OFF
        when 16 then GEOFENCE_EXIT_05

        when 20 then GPS_ACQUIRED
        when 25 then GPS_LOST
        when 30 then POWER_ON
        when 31 then MOTION
        when 32 then MOVING
        when 33 then MOTION_CLEARED
        when 35 then STOPPED

        when 40 then IDLING
        when 45 then IGNITION_ON

        when 50 then IGNITION_OFF
        when 55 then IGNITION_DISTANCE

        when 60 then TOWING
        when 65 then MAIN_POWER_LOW

        when 70 then BACKUP_POWER_LOW

        when 85 then MAIN_POWER_DISCONNECTED_CLEARED
        when 86 then MAIN_POWER_DISCONNECTED
        when 87 then INPUT_HIGH_04
        when 89 then INPUT_HIGH_03

        when 90 then INPUT_HIGH_02
        when 91 then INPUT_HIGH_01

        when 105 then OUTPUT_HIGH_01
        when 106 then OUTPUT_LOW_01
        when 107 then INPUT_LOW_04
        when 108 then INPUT_LOW_03
        when 109 then INPUT_LOW_02

        when 110 then INPUT_LOW_01
        when 115 then OUTPUT_HIGH_01
        when 116 then OUTPUT_HIGH_02

        when 255 then LOCATED
        else          "event_code_#{event_code}"
      end
    end

    def log_skipped_reading(message)
      Rails.logger.info "#{Time.now.utc.to_s(:db)} - Skipping reading because #{message}"
    end

    def exception_guard(&block)
      begin
        block.call
      rescue
        Rails.logger.info "TELEMATICS EXCEPTION: #{$!}"
        $@.each{|line| logger.info line}
      end
    end
  end
end
