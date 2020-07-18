MPH_10 = ConversionUtils.miles_to_km(10)
MPH_15 = ConversionUtils.miles_to_km(15)
MPH_20 = ConversionUtils.miles_to_km(20)
MPH_60 = ConversionUtils.miles_to_km(60)
MPH_80 = ConversionUtils.miles_to_km(80)

FactoryGirl.define do
  factory :reading do
    association :device
    gateway_event_type 'normal'
    recorded_at Time.now.utc.to_s(:db)
    latitude 1.2
    longitude 1.4
    speed 80
    data { { gps: { speed: MPH_80, head: 89.7 } } }

    factory :reading_with_geofence_and_location do
      association :geofence
      association :location
    end

    factory :reading_geofence_exit do
      updated_at '2011-04-12 09:52:30'
      geofence_event_type Reading::GEOFENCE_TYPE_EXIT
      association :geofence
      association :device, factory: :inactive_device
      gateway_event_type "exitgeofen_20"
      association :location
    end

    factory :reading_geofence_enter do
      updated_at DateTime.new(2002, 2, 3, 4, 5, 6)
      recorded_at DateTime.new(2001, 2, 3, 4, 5, 6)
      geofence_event_type Reading::GEOFENCE_TYPE_ENTER
      association :geofence, factory: :polygonal
      association :device, factory: :inactive_device
      gateway_event_type "entergeofen_20"
      association :location
    end

    factory :reading_location do
      ignition 0
      latitude '34.7956544975'
      longitude '-98.7835578179'
      recorded_at '2011-08-06 13:22:00'
      association :location
    end

    factory :reading_a_1 do
      association :device, factory: :device_a
      ignition 0
      latitude '34.7956544975'
      longitude '-98.7835578179'
      recorded_at '2011-08-06 13:22:00'
    end

    factory :reading_a_2 do
      association :device, factory: :device_a
      latitude '22'
      longitude '111'
      recorded_at '2011-08-06 13:25:00'
    end

    factory :reading_a_3 do
      association :device, factory: :device_a
      ignition 0
      latitude '123'
      longitude '65'
      recorded_at '2011-08-07 13:22:00'
    end

    factory :reading_update_recent_event1 do
      association :device, factory: :device_two
      latitude '32.905533'
      longitude '-96.819191'
      recorded_at '2012-05-28 14:48:13'
      ignition false
    end

    factory :reading_update_recent_event2 do
      association :device, factory: :device_two
      latitude '32.905533'
      longitude '-96.819191'
      recorded_at '2012-05-28 14:49:13'
      ignition false
      speed 0
    end

    factory :reading_update_recent_event3 do
      association :device, factory: :device_two
      latitude '32.905533'
      longitude '-96.819191'
      recorded_at '2012-05-28 14:53:54'
      ignition true
    end

    factory :trip_readings do
      speed MPH_20

      after :build do |r|
        d = Device.where(name: 'd_one').first
        d ||= FactoryGirl.create(:inactive_device)
        r.device = d
      end

      factory :readings_001 do
        recorded_at '2011-04-12 09:52:14'
        updated_at '2011-04-12 09:52:14'
        latitude '32.9479'
        longitude '-96.8234'
      end
    end
  end
end
