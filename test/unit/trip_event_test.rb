require 'test_helper'

class TripEventTest < ActiveSupport::TestCase
  fixtures :trip_events, :readings

  STD_GPS_DATA = { speed: ConversionUtils.miles_to_km(200), head: 39.5 }

  context 'update info' do
    setup do
      @t = trip_events(:two)
    end

    should 'call subsequent method when end_reading is valid' do
      @t.expects(:update_stats!).once
      @t.expects(:legs).once
      @t.expects(:save!).never
      @t.send(:update_info)
    end

    context 'end_reading nil' do
      setup do
        @t.end_reading = nil
      end

      should 'not call subsequent methods' do
        @t.expects(:update_stats!).never
        @t.expects(:legs).never
        @t.expects(:save!).never
        @t.send(:update_info)
      end
    end

    context 'end reading does not change' do
      setup do
        @t.start_reading = nil
      end

      should 'not invoke update_info callback' do
        @t.expects(:update_info).never
        @t.save
      end
    end
  end

  context 'legs method' do
    setup do
      Device.delete_all
      Reading.delete_all
      TripLeg.delete_all
      @device = Device.create(name: 'Testing Device', imei: '1122334455', thing_token: 'a1bc432')
      @start_reading = Reading.create(latitude: 1.2, longitude: 1.4, speed: 200, data: { gps: STD_GPS_DATA }, recorded_at: Time.now - 2.days, device_id: @device.id)
      @end_reading = Reading.create(latitude: 1.4, longitude: 1.6, speed: 200, data: { gps: STD_GPS_DATA }, recorded_at: Time.now - 1.days, device_id: @device.id)
      @trip_event = TripEvent.create(device_id: @device.id, start_reading_id: @start_reading.id, end_reading_id: @end_reading.id, started_at: @start_reading.recorded_at)
    end

    should 'should create a leg with properly trip_event_id' do
      @leg = @trip_event.legs
      assert_equal @trip_event, @leg.last.trip_event
    end

    should 'create a leg with properly start and stop reading' do
      @leg = @trip_event.legs
      assert_equal @start_reading, @leg.last.reading_start
      assert_equal @end_reading, @leg.last.reading_stop
    end

    should 'create a leg with properly duration' do
      @leg = @trip_event.legs
      expected_result = (@end_reading.recorded_at - @start_reading.recorded_at).round / 60
      assert_equal expected_result, @leg.last.duration
    end

    should 'return [] if trip_event start and stop reading are older than last stop reading on trip leg' do
      TripLeg.delete_all
      @trip_event.stubs(trip_legs: [TripLeg.create(reading_stop_id: @end_reading.id + 1)])
      assert @trip_event.legs.empty?
    end
  end

  context 'legs method for trip_event with stop inside' do
    setup do
      Device.delete_all
      Reading.delete_all
      TripLeg.delete_all
      TripEvent.delete_all
      StopEvent.delete_all
      @device = Device.create(name: 'Testing Device', imei: '1122334455', thing_token: 'a1bc433')
      @start_reading = Reading.create(latitude: 1.2, longitude: 1.4, speed: 200, data: { gps: STD_GPS_DATA }, recorded_at: Time.now - 3.days, device_id: @device.id)
      @mid_reading = Reading.create(latitude: 1.2, longitude: 1.4, speed: 200, data: { gps: STD_GPS_DATA }, recorded_at: Time.now - 2.days, device_id: @device.id)
      Reading.create(latitude: 1.4, longitude: 1.6, data: { gps: { head: 39.5 } }, recorded_at: Time.now - 36.hours, device_id: @device.id)
      @end_reading = Reading.create(latitude: 1.4, longitude: 1.6, speed: 200, data: { gps: STD_GPS_DATA }, recorded_at: Time.now - 1.days, device_id: @device.id)
      StopEvent.create(device_id: @device.id, started_at: (@start_reading.recorded_at + 2.hours), start_reading_id: @mid_reading.id)
      @trip_event = TripEvent.create(device_id: @device.id, start_reading_id: @start_reading.id, end_reading_id: @end_reading.id, started_at: @start_reading.recorded_at)

      @legs = TripLeg.all
    end

    should 'should create two trip_legs' do
      assert_equal 2, @legs.length
    end

    should 'create a trip leg with the same start reading as the trip event' do
      assert_equal @start_reading, @legs.first.reading_start
    end

    should 'create a trip leg with @mid_reading as end_reading' do
      assert_equal @mid_reading, @legs.first.reading_stop
    end

    should 'create a trip leg with the same end reading as the trip event' do
      assert_equal @end_reading, @legs.last.reading_stop
    end
  end

  context 'legs method for trip_event with stop inside and no readings after stop' do
    setup do
      setup do
        Device.delete_all
        Reading.delete_all
        TripLeg.delete_all
        TripEvent.delete_all
        StopEvent.delete_all
        @device = Device.create(name: 'Testing Device', imei: '1122334455', thing_token: 'a1bc434')
        @start_reading = Reading.create(latitude: 1.2, longitude: 1.4, speed: 200, data: { gps: STD_GPS_DATA }, recorded_at: Time.now - 3.days, device_id: @device.id)
        @mid_reading = Reading.create(latitude: 1.4, longitude: 1.6, speed: 200, data: { gps: STD_GPS_DATA }, recorded_at: Time.now - 2.days, device_id: @device.id)
        @trip_event = TripEvent.create(device_id: @device.id, start_reading_id: @start_reading.id, end_reading_id: @mid_reading.id, started_at: @start_reading.recorded_at)

        StopEvent.create(device_id: @device.id, started_at: (@start_reading.recorded_at + 2.hours), start_reading_id: @mid_reading.id)
        @legs = @trip_event.legs
      end
    end

    should 'should return nil' do
      assert_nil @legs
    end
  end

  context 'readings method' do
    setup do
      Device.delete_all
      @device = Device.create(name: 'Testing Device', imei: '1122334455', thing_token: 'a1bc435')
      @start_reading = Reading.create(latitude: 1.2, longitude: 1.4, speed: 200, data: { gps: STD_GPS_DATA }, recorded_at: Time.now - 2.days, device_id: @device.id)
      @end_reading = Reading.create(latitude: 1.4, longitude: 1.6, speed: 200, data: { gps: STD_GPS_DATA }, recorded_at: Time.now - 1.days, device_id: @device.id)
      @trip_event = TripEvent.new(device_id: @device.id, start_reading_id: @start_reading.id, end_reading_id: @end_reading.id, started_at: @start_reading.recorded_at)
    end

    should 'include start and end reading' do
      assert @trip_event.readings.include?(@start_reading)
      assert @trip_event.readings.include?(@end_reading)
    end
  end

  context 'update_stats method' do
    setup do
      Device.delete_all
      Reading.delete_all
      TripLeg.delete_all
      TripEvent.delete_all
      StopEvent.delete_all
      @device = Device.create(name: 'Testing Device', imei: '1122334455', thing_token: 'a1bc436')
      @start_reading = Reading.create(latitude: 1.2, longitude: 1.4, speed: 200, data: { gps: STD_GPS_DATA }, recorded_at: Time.now - 3.days, device_id: @device.id)
      @mid_reading = Reading.create(latitude: 1.4, longitude: 1.6, speed: 200, data: { gps: STD_GPS_DATA }, recorded_at: Time.now - 2.days, device_id: @device.id)
      @end_reading = Reading.create(latitude: 1.4, longitude: 1.6, speed: 200, data: { gps: STD_GPS_DATA }, recorded_at: Time.now - 1.days, device_id: @device.id)
      @trip_event = TripEvent.create(device_id: @device.id, start_reading_id: @start_reading.id, end_reading_id: @end_reading.id, started_at: @start_reading.recorded_at)
    end

    should 'return true' do
      assert @trip_event.update_stats!
    end

    should 'modify the distance correctly ' do
      assert_in_delta 19.5619, @trip_event.reload.distance, 0.0001
    end
  end
end
