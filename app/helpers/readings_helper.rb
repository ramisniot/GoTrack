module ReadingsHelper
  def hash_from_device(device, user)
    device.current_user = user

    methods = %i(dt full_dt helper_standard_location geofence address icon_id latitude longitude speed direction has_movement_alert_for_current_user last_gps_reading_id)

    device_hash = device.attributes
    methods.each { |method| device_hash[method] = device.send(method) }
    device_hash[:latest_status_html] = full_device_status(device)
    device_hash[:geofence_violations] = device.geofence_violations.map { |geofence_violation| geofence_violation.attributes }
    device_hash
  end

  def readings_for_device_js(readings)
    readings.reject { |reading| reading.short_address == ', ' }.map do |reading|
      {
        id: reading.id,
        lat: reading.latitude,
        speed: reading.speed,
        geofence: escape_javascript(reading.fence_description),
        lng: reading.longitude,
        address: escape_javascript(reading.short_address),
        device_phone_number: escape_javascript(reading.device_phone_number),
        direction: reading.direction,
        dt: standard_date_and_time(reading.recorded_at),
        note: escape_javascript(reading.note),
        event: reading.event_type
      }
    end.to_json
  end
end
