module Admin::DeviceHelper
  def digital_sensor_notification_type_options(sensor)
    options_for_select(
      [
        ['Disabled', DigitalSensor::NOTIFICATION_TYPES[:disabled]],
        ['High to Low', DigitalSensor::NOTIFICATION_TYPES[:high_to_low]],
        ['Low to High', DigitalSensor::NOTIFICATION_TYPES[:low_to_high]],
        ['Both', DigitalSensor::NOTIFICATION_TYPES[:both]]
      ],
      selected: sensor.notification_type
    )
  end
end
