class DigitalSensorReading < ActiveRecord::Base
  belongs_to :reading
  belongs_to :digital_sensor

  delegate :name, to: :digital_sensor, prefix: true

  def sensor_state
    value ? digital_sensor.high_label : digital_sensor.low_label
  end

  def description
    "#{digital_sensor.name} (#{sensor_state})"
  end
end
