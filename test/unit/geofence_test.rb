require File.dirname(__FILE__) + '/../test_helper'

class GeofenceTest < ActiveSupport::TestCase
  should validate_length_of(:name).is_at_most(Geofence::MAX_LENGTH[:name])
  should validate_presence_of(:latitude)
  should validate_presence_of(:longitude)
  should belong_to(:device)
  should belong_to(:account)
  should belong_to(:group)
  should have_many(:geofence_violations)
  should have_many(:polypoints)

  # TODO: Erase this once all fixtures are removed
  setup do
    Geofence.destroy_all
    Device.delete_all
  end

  context '.by_area' do
    setup do
      @fence1 = FactoryGirl.create(:geofence, radius: 2)
      @fence2 = FactoryGirl.create(:geofence, radius: 5)
      @fence3 = FactoryGirl.create(:geofence, radius: 1)
    end

    should 'return the fences in ascending order by area' do
      assert_equal([@fence3, @fence1, @fence2], Geofence.by_area.to_a)
    end
  end

  context '.by_updated_at' do
    setup do
      @fence1 = FactoryGirl.create(:geofence, radius: 2)
      @fence2 = FactoryGirl.create(:geofence, radius: 5)
    end

    should 'return the fences in descending order by updated_at' do
      assert_equal([@fence2, @fence1], Geofence.by_updated_at.to_a)
    end
  end

  context 'geofence violation destroy trigger' do
    setup do
      @geofence = FactoryGirl.create(:circular)
      @geofence.geofence_violations.create(device_id: @geofence.device_id, violation_time: Time.now)
    end

    should 'erase geofences violations on geofence destroy' do
      assert_difference 'GeofenceViolation.count', -1 do
        @geofence.destroy
      end
    end
  end

  context '.location_from_address' do
    should 'return an array with lat long values' do
      lat = 10
      long = 20
      address = "#{lat}, #{long}"
      assert_equal([lat.to_s, long.to_s], Geofence.location_from_address(address))
    end
  end

  context '.relevant_geofences_for_device' do
    setup do
      @device = FactoryGirl.build(:device, account_id: 1)
    end

    should 'return a blank relation if there are no relevant geofences for a device' do
      assert_empty(Geofence.relevant_geofences_for_device(@device))
    end

    should 'return a relation with the relevant fence if it exists' do
      fence = FactoryGirl.create(:geofence, account_id: 1, radius: 1)
      assert_equal(fence, Geofence.relevant_geofences_for_device(@device).first)
    end
  end

  context '.within_latitudes' do
    should 'returns a blank relationship' do
      assert_empty(Geofence.within_latitudes(-10, 10))
    end

    should 'return the fences that are within the latitudes' do
      fence = FactoryGirl.create(:geofence, radius: 10)
      assert_equal(fence, Geofence.within_latitudes(30, 33).first)
    end
  end

  context '.within_longitudes' do
    should 'return a blank relationship if no fences exist' do
      assert_empty(Geofence.within_longitudes(-10, 10))
    end

    should 'return the fences that are withing longitudes' do
      fence = FactoryGirl.create(:geofence, radius: 10)
      assert_equal(fence, Geofence.within_longitudes(-95, -97).first)
    end
  end

  context '.change_vertical_axis' do
    should 'return -180 + lng value if lng > 0 and relative is true' do
      lng = 20
      assert_equal(lng - 180, Geofence.change_vertical_axis(lng))
    end

    should 'return 180 + lng value if lng < 0 and relative is true' do
      lng = -20
      assert_equal(180 + lng, Geofence.change_vertical_axis(lng))
    end

    should 'return -180 + lng valsue if lng > 0 and relative is false' do
      lng = 20
      assert_equal(lng - 180, Geofence.change_vertical_axis(lng, false))
    end

    should 'return 180 + lng valddue if lng < 0 and relative is false' do
      lng = -20
      assert_equal(180 + lng, Geofence.change_vertical_axis(lng, false))
    end
  end

  context '.between_bounds' do
    should 'return true if lng is between bounds and left_bound < right_bound' do
      assert(Geofence.between_bounds?(100, 10, 1000))
    end

    should 'return false if lng is not between bounds and left_bound < right_bound' do
      refute(Geofence.between_bounds?(30, 10, 20))
    end

    should 'return true if lng is between left_bound and max_longitude if left_bound > right_bound' do
      assert(Geofence.between_bounds?(30, 10, 5))
    end
  end

  context '#set_center_and_radius' do
    should 'if polygonal set the latitude and longitude of the geofence with lat long averages' do
      geofence = FactoryGirl.create(:polygonal)
      polypoints = [GeofencePolypoint.new(latitude: 10, longitude: 10), GeofencePolypoint.new(latitude: 0, longitude: 0), GeofencePolypoint.new(latitude: 20, longitude: 20)]
      geofence.polypoints = polypoints
      geofence.set_center_and_radius

      assert_equal(10, geofence.latitude)
      assert_equal(10, geofence.longitude)
    end

    should 'if not polygonal set the area as the squared of the radius times PI' do
      geofence = FactoryGirl.create(:circular, radius: 1)
      geofence.set_center_and_radius

      assert_equal(Math::PI, geofence.area)
    end
  end

  context '#square_bounds_for_circular_shape' do
    setup do
      @fence = FactoryGirl.build(:circular, radius: 100)
      @p1 = [@fence.latitude - (@fence.radius * Overlay::MILES_TO_DEGREES), @fence.longitude - (@fence.radius * Overlay::MILES_TO_DEGREES)]
      @p2 = [@fence.latitude + (@fence.radius * Overlay::MILES_TO_DEGREES), @fence.longitude + (@fence.radius * Overlay::MILES_TO_DEGREES)]

    end
    should 'return the lat long of the square_bounds' do
      assert_equal(@p1.concat(@p2).map!(&:to_i), @fence.square_bounds_for_circular_shape.map!(&:to_i))
    end
  end

  context '#square_bounds_for_polygonal_or_rectangular_shape' do
    should 'return the lat long of the square_bounds' do
      fence = FactoryGirl.build(:rectangular)
      pointsX = fence.effective_polypoints.collect(&:longitude).collect(&:to_i)
      pointsY = fence.effective_polypoints.collect(&:latitude).collect(&:to_i)
      bounds = [pointsY.min, pointsX.min, pointsY.max, pointsX.max]

      assert_equal(bounds, fence.square_bounds_for_polygonal_or_rectangular_shape.map!(&:to_i))
    end

    should 'return the lat long of the square_bounds for geofences across antimeridian' do
      fence = FactoryGirl.build(:rectangular_AM)
      pointsX = fence.effective_polypoints.collect(&:longitude).collect(&:to_i)
      pointsY = fence.effective_polypoints.collect(&:latitude).collect(&:to_i)
      bounds = [pointsY.min, pointsX.max, pointsY.max, pointsX.min]

      assert_equal(bounds, fence.square_bounds_for_polygonal_or_rectangular_shape.map!(&:to_i))
    end
  end

  context '#address_or_coords' do
    setup do
      @fence = FactoryGirl.build(:geofence, radius: 10);
    end

    should 'return the address if address is a string' do
      @fence.address = 'venice beach'
      assert_equal(@fence.address_or_coords, @fence.address)
    end

    should 'return the coords as string if the address is an empty string' do
      @fence.address = '';
      response = sprintf("%0.5f, %0.5f", @fence.latitude.to_f, @fence.longitude.to_f)
      assert_equal(response, @fence.address_or_coords)
    end
  end

  context '#effective_polypoints' do
    should 'return an empty array for circular fences' do
      fence = FactoryGirl.build(:circular)
      assert_equal([], fence.effective_polypoints)
    end

    should 'return the polypoints for polygonal fences' do
      fence = FactoryGirl.build(:polygonal)
      assert_equal(fence.polypoints, fence.effective_polypoints)
    end

    should 'return the polypoints of rectangular fences if they exist' do
      fence = FactoryGirl.build(:rectangular)
      polypoints = [GeofencePolypoint.new(latitude: 10, longitude: 10)]
      fence.polypoints = polypoints

      assert_equal(polypoints, fence.effective_polypoints)
    end
  end

  context '#polypoint_string=' do
    setup do
      @fence = FactoryGirl.build(:polygonal)
    end

    should 'set the fences polypoints' do
      points = "[53.42832368106438,-3.0524544417858124]:[53.427940126919175,-3.0442146956920624]:[53.42502500231362,-3.0448584258556366]"
      @fence.polypoint_string=(points)
      assert(@fence.polypoints.any?)
    end
  end

  context '#encloses?' do
    setup do
      @reading = FactoryGirl.build(:reading)
    end

    context 'for circular fences' do
      setup do
        @fence = FactoryGirl.build(:circular, radius: 100)
      end

      should 'return false if no args are given' do
        refute(@fence.encloses?)
      end

      should 'return false if the reading passed is outside the fence' do
        refute(@fence.encloses?(@reading))
      end

      should 'return true if the reading passed is inside the fence' do
        reading = FactoryGirl.build(:reading, latitude: 32, longitude: -96)
        assert(@fence.encloses?(reading))
      end
    end

    context 'for polygonal fences' do
      setup do
        @fence = FactoryGirl.build(:polygonal)
        @polypoints = [GeofencePolypoint.new(latitude: 10, longitude: 10), GeofencePolypoint.new(latitude: 0, longitude: 0), GeofencePolypoint.new(latitude: 20, longitude: 20)]
        @fence.polypoints = @polypoints
      end

      should 'return false if the reading is outside the polygon' do
        refute(@fence.encloses?(@reading))
      end

      should 'return false for fences across antimeridian if reading is outside fence' do
        fence = FactoryGirl.build(:normal_across_antimeridian_geofence)
        polypoints = [GeofencePolypoint.new(latitude: 10, longitude: 10)]
        fence.polypoints = polypoints

        refute(fence.encloses?(@reading))
      end
    end

    context 'for rectangular fences' do
      setup do
        @fence = FactoryGirl.build(:rectangular)
      end
      should 'return false if the reading passed is outside the fence' do
        refute(@fence.encloses?(@reading))
      end
    end
  end

  context '#calculate_geofence_center' do
    should 'return the center of the fence' do
      fence = FactoryGirl.build(:rectangular)
      fenceCenter = [fence.tl_lat, fence.tl_lng]
      assert_equal(fenceCenter.map!{ |x| x.to_f.round(2) }, fence.calculate_geofence_center.map!{ |x| x.to_f.round(2) })
    end

    should 'also return the center if the fence is across an antimeridian' do
      fence = FactoryGirl.build(:rectangular_AM)
      assert_equal([-5, -175], fence.calculate_geofence_center.map!(&:to_f))
    end
  end
end
