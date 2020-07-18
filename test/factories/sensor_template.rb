FactoryGirl.define do
  factory :sensor_template do |st|
    st.association :account
    st.name 'Sensor Template'
    st.address 1
    st.low_label 'Low'
    st.high_label 'High'
    st.notification_type DigitalSensor::NOTIFICATION_TYPES[:disabled]
  end
end