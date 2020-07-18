class TestReadingGenerator
  def initialize(latitude: '32.843848', longitude: '-96.744911', device:, event_type: 'normal', speed: '0.0', ignition: '1')
    timestamp = Time.now.strftime('%Y-%m-%dT%H:%M:%S.%L%z')

    reading = {
      id:   '54de2a0582cf002b210b4ec6',
      type: 'reading',
      data: {
        device_name:              device.imei,
        device_name_type:         'imei',
        device_port:              '51269',
        device_type:              device.gateway_name,
        event_parse_method:       'legacy',
        event_timestamp:          timestamp,
        event_timestamp_source:   'rtc_timestamp',
        event_type:               event_type,
        gps_altitude:             '216.0',
        gps_fix_type:             '2',
        gps_heading:              '0.0',
        gps_latitude:             latitude,
        gps_longitude:            longitude,
        gps_number_of_satellites: '8',
        gps_odometer:             '0',
        gps_speed:                speed,
        gps_timestamp:            timestamp,
        ignition:                 ignition,
        internal_power_level:     '40',
        rtc_timestamp:            timestamp,
        sequence_number:          '125',
        sms_account_id:           '5621'
      },
      timestamp: timestamp,
      headers: {}
    }

    connection = NumerexStomper::Base.connection_string_for(Rails.env)
    queue = NumerexStomper::Base.configuration['destinations']['telematics']
    client = Stomp::Client.new("#{connection}:61613}")
    client.publish(queue, reading.to_json)
    client.close
  end
end
