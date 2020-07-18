class DigitalSensor < ActiveRecord::Base
  belongs_to :device
  belongs_to :last_digital_sensor_reading, class_name: 'DigitalSensorReading'

  validates :address, uniqueness: { scope: :device_id, message: 'should have one digital sensor per address' }

  NOTIFICATION_TYPES = {
    disabled: 0,
    high_to_low: 1,
    low_to_high: 2,
    both: 3
  }

  def high_to_low_notifications?
    notification_type == NOTIFICATION_TYPES[:high_to_low] || notification_type == NOTIFICATION_TYPES[:both]
  end

  def low_to_high_notifications?
    notification_type == NOTIFICATION_TYPES[:low_to_high] || notification_type == NOTIFICATION_TYPES[:both]
  end

  def self.build_sensor(address, template)
    if template
      DigitalSensor.new(template.attributes.select { |key, _| [:name, :address, :high_label, :low_label, :notification_type].include?(key.to_sym) })
    else
      DigitalSensor.new(
        name: "Digital Sensor #{address}",
        address: address,
        high_label: 'High',
        low_label: 'Low',
        notification_type: NOTIFICATION_TYPES[:disabled]
      )
    end
  end

  def should_notify?(event_type, new_value)
    value_change?(new_value) && (should_notify_low_to_high?(event_type) || should_notify_high_to_low?(event_type))
  end

  def value_change?(new_value)
    last_digital_sensor_reading.try(:value) != new_value
  end

  def create_new_digital_sensor_reading(reading, input_value)
    digital_sensor_reading = DigitalSensorReading.create(
      reading_id: reading.id,
      digital_sensor_id: self.id,
      value: input_value,
      recorded_at: reading.recorded_at,
      received_at: reading.received_at
    )

    if should_notify?(reading.event_type, input_value)
      device.on_subscribed_users(:sensor) { |user| DigitalSensorMailer.digital_sensor_mail(user, reading).deliver_now }
    end

    self.update_attributes(last_digital_sensor_reading: digital_sensor_reading)
  end

  def self.default_sensor(address)
    DigitalSensor.new(name: "Digital Sensor #{address}", address: address, high_label: 'High', low_label: 'Low', notification_type: NOTIFICATION_TYPES[:disabled])
  end

  private

  def should_notify_low_to_high?(event_type)
    low_to_high_notifications? && event_type == EventTypes::AssetLowToHigh
  end

  def should_notify_high_to_low?(event_type)
    high_to_low_notifications? && event_type == EventTypes::AssetHighToLow
  end
end
