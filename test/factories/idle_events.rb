FactoryGirl.define do
  factory :idle_event do
    factory :recent_event_update2 do
      association :device, factory: :device_two
      created_at "2012-05-28 15:57:39"
      started_at     "2011-08-06 13:22:00"
      ended_at       "2011-08-06 13:25:00"
    end
  end
end
