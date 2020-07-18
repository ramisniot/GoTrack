require 'test_helper'

class TripLegTest < ActiveSupport::TestCase
  setup do
    @reading = Reading.create(recorded_at: Time.now, latitude: 1.2, longitude: 1.4)
  end

  test 'latitude method should return latitude from start reading' do
    trip_leg = TripLeg.new(reading_start_id: @reading.id)
    assert_equal @reading.latitude, trip_leg.latitude
  end

  test 'longitude method should return latitude from start reading' do
    trip_leg = TripLeg.new(reading_start_id: @reading.id)
    assert_equal @reading.longitude, trip_leg.longitude
  end

  context 'stop_duration' do
    setup do
      now = DateTime.now
      DateTime.stubs(:now).returns(now)

      @trip_leg = TripLeg.new(reading_start: Reading.new(recorded_at: DateTime.now - 5.hours))
    end

    should 'return nil if next_leg_start is nil' do
      assert_nil @trip_leg.stop_duration(nil)
    end

    context 'when next_leg_start is not nil' do
      should 'return nil if stop_reading is nil' do
        assert_nil @trip_leg.stop_duration(DateTime.now)
      end
    end
  end
end
