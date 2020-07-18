FactoryGirl.define do
  factory :trip_leg do
    association :device
    association :trip_event
    suspect false
    reading_start_id 6
    reading_stop_id 13
    started_at Time.now
    stopped_at Time.now + 1.days
    created_at Time.now.to_s :db
    duration 9
  end
end
