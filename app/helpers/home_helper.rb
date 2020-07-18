module HomeHelper
  def update_readings_automatically?
    params[:action] != "vehicle_status" && params[:action] != "maintenance"
  end

  def show_device_location(device)
    show_device(device, true)
  end

  def show_device_status(device)
    show_device(device, false)
  end

  def show_device(device, show_location)
    content = ""
    content << %(<tr id="row#{device.id}"> <td>)
    if device.last_gps_reading
      if show_location
        content << %(<a href="javascript:focusOnAndFollow(#{device.id});" title="Center map on this device" class="link-all1">#{device.name}</a>)
      else
        content << %(<a href="/reports/trip/#{device.id}" title="View details" class="link-all1">#{device.name}</a>)
      end
    else
      content << %(#{device.name})
    end
    if device.request_location? && !current_user.is_read_only?
      content << %(&nbsp;<input type="button" value="Find Now" onclick="location.href='/devices/find_now/#{device.id}?original_referral_url='+document.location.href+'?highlight=#{device.id}';" />)
    end
    content << %(</td>)

    content << %(<td>)
    if device.last_gps_reading
      content << standard_location(device, device.last_gps_reading, false)
    else
      content << %(N/A)
    end
    content << %(</td>)

    content << %(<td>)
    content << full_device_status(device)
    content << %(</td>)

    content << %(<td>)
    if device.last_gps_reading
      content << standard_date_and_time(device.last_gps_reading.recorded_at)
    else
      content << %(N/A)
    end
    content << %(</td>)
    content << %(</tr>)

    content.html_safe
  end

  def show_statistics(device)
    # TODO replace with real data
    @stop_total ||= 1
    @idle_total ||= 2.0
    @runtime_total ||= 40.0
    idle_percentage = sprintf("%2.2f", @idle_total / @runtime_total * 100)
    runtime_percentage = sprintf("%2.2f", @runtime_total / (7 * 24) * 100)

    content = ""
    content << %(<tr class="#{cycle('dark-row', 'light-row')}" id="row#{device.id}"> <td>)
    if device.last_gps_reading
      content << %(<a href="javascript:focusOnAndFollow(#{device.id});" title="Center map on this device" class="link-all1">#{device.name}</a>)
    else
      content << %(#{device.name})
    end
    content << %(</td>
    <td style="font-size:11px;">
      <a href="/reports/all/#{device.id}" title="View device details" class="link-all1">details</a>
    </td>
    <td style="text-align:right;">#{@stop_total}<td style="text-align:right;">#{@idle_total}<td style="text-align:right;">#{idle_percentage}<td style="text-align:right;">#{@runtime_total}<td style="text-align:right;">#{runtime_percentage})

    @stop_total += 1
    @idle_total += 2
    @runtime_total -= 2

    content.html_safe
  end

  def entities(str)
    converted = []
    str.split(//).collect { |c| converted << (c[0].ord > 127 ? "&##{c[0]};" : c) }
    converted.join('')
  end

  def add_device_js(device, override = {})
    return '' if device.last_gps_reading.nil? || device.last_gps_reading.short_address == ', '
    device.current_user = current_user
    attributes = {
      id: device.id,
      name: device.name,
      lat: device.last_gps_reading.latitude,
      lng: device.last_gps_reading.longitude,
      address: entities(standard_location(device, device.last_gps_reading, request.format.mobile?, browser.device.mobile?)),
      phone_number: device.phone_number,
      dt: device.dt,
      full_dt: standard_full_datetime(device.last_gps_reading.recorded_at),
      geofence: device.last_gps_reading.fence_description,
      helper_standard_location: device.helper_standard_location(browser.device.mobile?),
      has_movement_alert_for_current_user: device.has_movement_alert_for_current_user,
      note: device.last_gps_reading.note,
      status: full_device_status(device),
      direction: device.last_gps_reading.direction,
      speed: device.last_gps_reading.speed,
      icon_id: device.icon_id,
      group_id: device.group_id,
      last_gps_reading_id: device.last_gps_reading_id
    }

    attributes.update(override)

    "<script>devices.push(#{attributes.to_json.html_safe});</script>".html_safe
  end

  def devices_in_group_and_dispatchable(group, dispatchable_devices)
    group.devices.where(dispatchable_devices.blank? ? nil : { id: dispatchable_devices }).includes(last_gps_reading: [:geofence, :location, :digital_sensor_reading])
  end
end
