xml.instruct! :xml, :version=>"1.0"
xml.devices do
  @devices.each do |device|
    xml.device do
      xml.id(device.id)
      xml.name(device.name)
      xml.imei(device.imei)
       xml.icon_id(device.icon_id)
        # Just display empty nodes if this device has no readings
      if device.last_gps_reading.nil?
        xml.lat
        xml.lng
        xml.address
        xml.dt
        xml.note
        xml.status
        xml.direction
        xml.geofence
        xml.speed
      else # We got data
        xml.lat(device.last_gps_reading.latitude)
        xml.lng(device.last_gps_reading.longitude)
        xml.address(standard_location(device,device.last_gps_reading))
        xml.geofence(device.last_gps_reading.fence_description)
        xml.dt(standard_date_and_time(device.last_gps_reading.recorded_at,Time.now))
        xml.note(device.last_gps_reading.note)
        xml.status(full_device_status(device))
        xml.direction(device.last_gps_reading.direction)
        xml.speed(device.last_gps_reading.speed || 0)
      end
    end
  end
end
