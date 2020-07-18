module MobileHelper
  def mobile_show_device(device, flag)
    content = ""
    content << %(<li>)
    if device.last_gps_reading
      content << %(<strong>#{@range[@all_devices_with_map.index(device)]}: </strong>) unless flag
      content << %(<a href="/mobile/show_device/#{device.id}" title="Center map on this device">#{device.name}</a>)
      content << %(&nbsp;&nbsp;(#{time_ago_in_words device.last_gps_reading.recorded_at} ago)<br/>)
      content << %(#{device.last_gps_reading.short_address})
      @center = "37.0625, -95.677068" if !flag && @center == ""
      @marker_string = @marker_string + "#{device.last_gps_reading.latitude},#{device.last_gps_reading.longitude},#{MAP_MARKER_COLOR[device.icon_id - 1]}#{@range[@all_devices_with_map.index(device)].downcase}%7C" unless flag
    else
      content << %(<strong>#{@range[@all_devices_with_map.index(device)]}: </strong>) unless flag
      content << %(#{device.name})
      content << %( &nbsp;N/A<br/>)
      content << %(N/A)
    end
    content << %(</li>)
    content.html_safe
  end
end
