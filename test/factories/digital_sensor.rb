FactoryGirl.define do
  factory :digital_sensor do
    association :device
    name 'Digital Sensor'
    address 1
    low_label 'Low'
    high_label 'High'
    notification_type DigitalSensor::NOTIFICATION_TYPES[:disabled]
  end
end
