FactoryGirl.define do
  factory :digital_sensor_reading do |dsr|
    dsr.association :digital_sensor
    dsr.value true
  end
end