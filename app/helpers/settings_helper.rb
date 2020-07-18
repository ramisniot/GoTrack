module SettingsHelper
  def hour_dropdown(input_name = 'working_hours', selected_hour = nil)
    select_tag(input_name, options_for_select([
      ['', ''],
      ['12:00am', '0000'],      ['12:30am', '0030'],
      ['01:00am', '0100'],      ['01:30am', '0130'],
      ['02:00am', '0200'],      ['02:30am', '0230'],
      ['03:00am', '0300'],      ['03:30am', '0330'],
      ['04:00am', '0400'],      ['04:30am', '0430'],
      ['05:00am', '0500'],      ['05:30am', '0530'],
      ['06:00am', '0600'],      ['06:30am', '0630'],
      ['07:00am', '0700'],      ['07:30am', '0730'],
      ['08:00am', '0800'],      ['08:30am', '0830'],
      ['09:00am', '0900'],      ['09:30am', '0930'],
      ['10:00am', '1000'],      ['10:30am', '1030'],
      ['11:00am', '1100'],      ['11:30am', '1130'],
      ['12:00pm', '1200'],      ['12:30pm', '1200'],
      ['01:00pm', '1300'],      ['01:30pm', '1330'],
      ['02:00pm', '1400'],      ['02:30pm', '1430'],
      ['03:00pm', '1500'],      ['03:30pm', '1530'],
      ['04:00pm', '1600'],      ['04:30pm', '1630'],
      ['05:00pm', '1700'],      ['05:30pm', '1730'],
      ['06:00pm', '1800'],      ['06:30pm', '1830'],
      ['07:00pm', '1900'],      ['07:30pm', '1930'],
      ['08:00pm', '2000'],      ['08:30pm', '2030'],
      ['09:00pm', '2100'],      ['09:30pm', '2130'],
      ['10:00pm', '2200'],      ['10:30pm', '2230'],
      ['11:00pm', '2300'],      ['11:30pm', '2330'],
      ['midnight', '2400']], selected_hour), { class: 'form-select' })
  end

  def notification_type_description(notification_type)
    case notification_type
      when :offline
        'Device goes offline'
      when :idling
        'Idling'
      when :sensor
        'Sensor Input'
      when :speed
        'Speed'
      when :geofence
        'Geofence'
      when :gpio
        'General-purpose input/output'
      when :first_movement
        'First movement'
      when :startup
        'Startup'
      when :gps_unit_power
        'GPS unit power'
      when :maintenance
        'Maintenance'
    end
  end
end
