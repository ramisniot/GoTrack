FactoryGirl.define do
  factory :trip_event do
    association :device
    association :start_reading, factory: :readings_001
    started_at Time.now
    ended_at Time.now + 1.days
    duration 12
    start_latitude '32.9479'
    end_latitude '32.9407'
    start_longitude '-96.8234'
    idle_events_quantity 0

    start_reading_id 6
    end_reading_id 13
  end
end
