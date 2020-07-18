module DeviceHelper
  DEVICE_NAME_MAX_LENGTH = 40

  def idle_alert_threshold_options(selected)
    idle_alert_minutes = (1..12).map { |x| 5 * x } + (3..20).map { |x| 30 * x }
    options_for_select([['Disable', 0]] + idle_alert_minutes.map { |x| ["#{x} minutes", x * 1.minutes] }, selected)
  end

  def submit_colspan(device)
    device.max_digital_sensors && device.max_digital_sensors > 0 ? device.max_digital_sensors + 1 : 2
  end

  def devices_for_account(account, selected_device_id = nil)
    select(
      :search,
      :device_id,
      account.devices.collect { |d| [d.name, d.id] },
      { include_blank: true, selected: selected_device_id },
      { onchange: 'this.form.submit();' }
    )
  end

  def device_short_name(device)
    device_name = device.name

    return device_name if device_name.length <= DEVICE_NAME_MAX_LENGTH

    "#{device_name[Range.new(0, DEVICE_NAME_MAX_LENGTH - 4)]}..."
  end
end
