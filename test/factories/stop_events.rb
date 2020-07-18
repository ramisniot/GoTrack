FactoryGirl.define do
  factory :stop_event do

    factory :stop_event_1 do
      association :device, factory: :device_a
      started_at     "2011-08-06 13:22:00"
      ended_at       "2011-08-06 13:25:00"
      duration 5
    end

    factory :stop_event_2 do
      association :device, factory:         :device_a
      association :start_reading, factory:  :reading_a_3
      started_at     "2011-08-07 13:22:00"
    end

    factory :recent_event_update1 do
      association :device, factory: :device_two
      association :start_reading, factory: :reading_update_recent_event2
      started_at "2012-05-28 14:49:24"
    end

    factory :recent_event_update3 do
      association :device, factory: :device_two
      association :start_reading, factory: :reading_update_recent_event1
      started_at "2012-05-28 14:48:13"
    end
  end
end
