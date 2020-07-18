FactoryGirl.define do
  factory :geofence_violation do
    association :device, factory: :active_device
    geofence { FactoryGirl.create(:geofence_1, account_id: device.account_id) }
    violation_time Time.now
  end
end