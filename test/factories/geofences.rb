FactoryGirl.define do
  factory :geofence do
    sequence(:name) { |n| "geofence_#{n}" }
    latitude 32.7956
    longitude (-96.7835)
    radius 4
    association :account, factory: :test_account

    factory :polygonal do
      name 'Downtown'
      device_id 0
      latitude '32.7956544975'
      longitude '-96.7835578179'
      address 'Dallas, TX'
      radius 3.48924
      shape_type Geofence::SHAPE_POLYGONAL
      color 'green'
      area 13.1333
      fence_num 1
      created_at '2011-04-07 23:03:03 Z'
      updated_at '2011-04-07 23:03:03 Z'
    end

    factory :circular do
      name 'Numerex Offices'
      device_id 0
      latitude '32.9424046'
      longitude '-96.8217765'
      address '14185 Dallas Pkwy Suite 500 Dallas, TX 75254'
      radius 0.25
      shape_type Geofence::SHAPE_CIRCULAR
      color 'blue'
      fence_num 0
      area 0.19635
      created_at '2011-04-07 23:04:28 Z'
      updated_at '2011-04-07 23:04:28 Z'
    end

    factory :rectangular do
      name 'Numerex Offices'
      association :device, factory: :inactive_device
      latitude 32.9424046
      longitude (-96.8217765)
      tl_lat '32.9425046'
      tl_lng '-96.8218765'
      br_lat '32.9423046'
      br_lng '-96.8216765'
      fence_num 2
      address '14185 Dallas Pkwy Suite 500 Dallas, TX 75254'
      shape_type Geofence::SHAPE_RECTANGULAR
      color 'red'
      area 0.22635
      created_at '2011-04-07 23:04:28 Z'
      updated_at '2011-04-07 23:04:28 Z'
    end

    factory :rectangular_AM do
      name 'across antimeridian'
      latitude '10'
      longitude '180'
      tl_lat 30
      tl_lng 160
      br_lat (-40)
      br_lng (-150)
      shape_type Geofence::SHAPE_RECTANGULAR
      color 'red'
      created_at '2011-04-07 23:04:28 Z'
      updated_at '2011-04-07 23:04:28 Z'
    end

    factory :geofence_1 do
      shape_type Geofence::SHAPE_RECTANGULAR
      latitude  26.7073
      longitude (-80.0382)
      br_lat 26.6922
      br_lng (-80.0302)
      tl_lat 26.7227
      tl_lng (-80.04612)
    end

    factory :fence1 do
      name 'Downtown'
      latitude 32.7956544975
      longitude (-96.7835578179)
      address 'Dallas, TX'
      radius 3.48924
      area 13.1333
      color 'green'
      created_at '2011-04-07 23:03:03'
      updated_at '2011-04-07 23:03:03'
    end

    factory :normal_across_antimeridian_geofence do
      name 'poly a_antimeridian'
      color 'blue'
      shape_type Geofence::SHAPE_POLYGONAL
      created_at '2011-04-07 23:03:03'
      updated_at '2011-04-07 23:03:03'
    end
  end
end
