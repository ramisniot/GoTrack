require 'test_helper'

class EventState::SpanningTest < ActiveSupport::TestCase

  def setup
    EventState::Base.reset_cache
    @next_timestamp = Time.now - 2.hours
    EventState::Base.for_device(@device = FactoryGirl.create(:inactive_device)) {|state| @state = state} # NOTE - this technique is dangerous in a real multi-threaded situation
  end

  context 'constants' do
    context 'MIN_STOP_IDLE_SECONDS' do
      should 'be three minutes' do
        assert_equal 3 * 60, EventState::Spanning::MIN_STOP_IDLE_SECONDS
      end
    end

    context 'MAX_EXPIRED_SECONDS' do
      should 'be three hours' do
        assert_equal 60 * 60 * 3 , EventState::Spanning::MAX_EXPIRED_SECONDS
      end
    end
  end

  context 'open_trip_count' do
    should 'be 0 if there is no open_trip' do
      assert_equal 0,EventState::Base.open_trip_count
    end

    should 'return the count of open trips' do
      first_reading = start_time = nil
      assert_trip_idle_stop_differences(1, 0, 0) { first_reading = consider_next_reading(recorded_at: start_time = (next_timestamp(-1 * EventState::Base::MAX_EXPIRED_SECONDS)), speed: 15, data: {eng: {ign: 1}, gps: {speed: MPH_15 }}, latitude: '36.1611893840757', longitude: '-86.81426620976718') }
      assert last_trip_event = @device.open_trip_event
      assert_equal 1, EventState::Base.open_trip_count
      assert_event_state(last_trip_event, first_reading, nil, nil, false)
    end
  end

  context 'trip flow' do
    should 'correctly set calculated attributes' do
      assert_equal 0,EventState::Base.open_trip_count

      first_reading = start_time = nil
      assert_trip_idle_stop_differences(1, 0, 0) { first_reading = consider_next_reading(recorded_at: start_time = (next_timestamp(-1 * EventState::Base::MAX_EXPIRED_SECONDS)), speed: 15, data: {eng:{ign: 1},gps:{speed: MPH_15}}, latitude: '36.1611893840757', longitude: '-86.81426620976718') }
      assert last_trip_event = @device.open_trip_event
      assert_event_state(last_trip_event, first_reading, nil, nil, false)
      assert_equal 1, EventState::Base.open_trip_count
      assert_equal [first_reading.recorded_at.to_s(:db), @device.id.to_s],@state.open_trip_key.split('$')

      end_reading = end_time = nil
      assert_trip_idle_stop_differences(0, 0, 0) { end_reading = consider_next_reading(recorded_at: end_time = (next_timestamp(+0.5 * EventState::Base::MAX_EXPIRED_SECONDS)), speed: 20, data: {eng:{ign: 1},gps:{speed: MPH_20}}, latitude: '36.1611893840757', longitude: '-86.81426620976718') }

      EventState::Base.end_expired_open_trips
      assert_equal 0, EventState::Base.open_trip_count
      assert_nil @device.open_trip_event
      assert_event_state(last_trip_event, first_reading,end_reading, (end_time - start_time).round, false)

      assert_equal 2, last_trip_event.speeds_quantity
      assert_equal 15 + 20, last_trip_event.speeds_sum
      assert_equal (15 + 20) / 2, last_trip_event.average_speed
      assert_equal 20, last_trip_event.max_speed
      assert !last_trip_event.suspect
      assert_equal 0,last_trip_event.idle_duration
      assert_nil last_trip_event.idle_events_quantity
    end
  end

  context 'open trip' do
    should 'open trip processing' do
      assert_equal 0,EventState::Base.open_trip_count
      assert_nothing_raised { EventState::Base.end_expired_open_trips }

      first_reading = nil
      assert_trip_idle_stop_differences(1, 0, 0) { first_reading = consider_next_reading(recorded_at: next_timestamp(-2 * EventState::Base::MAX_EXPIRED_SECONDS), speed: 15, data: {eng:{ign: 1},gps:{speed: MPH_15}}, latitude: '36.1611893840757', longitude: '-86.81426620976718') }
      assert_not_nil last_trip_event = @device.open_trip_event
      assert_event_state(last_trip_event, first_reading, nil, nil, false)
      assert_equal 1, EventState::Base.open_trip_count
      assert_equal [first_reading.recorded_at.to_s(:db), @device.id.to_s], @state.open_trip_key.split('$')

      EventState::Base.reset_cache
      assert_equal 0, EventState::Base.open_trip_count

      EventState::Base.ensure_caching_for_open_trips
      assert_equal 1, EventState::Base.open_trip_count

      EventState::Base.for_device(@device) {|state| @state = state} # NOTE - this technique is dangerous in a real multi-threaded situation
      @device = @state.device
      assert_not_nil last_trip_event = @device.open_trip_event

      EventState::Base.end_expired_open_trips
      assert_equal 0, EventState::Base.open_trip_count
      assert_nil @device.open_trip_event
      assert_event_state(last_trip_event, first_reading, first_reading, 0, true)

      assert_nothing_raised { @state.end_open_trip }
    end

    should 'open a stop event if the first message to arrive has false ignition' do
      first_reading = nil
      assert_trip_idle_stop_differences(0, 0, 1) { first_reading = consider_next_reading(recorded_at: next_timestamp, speed: 0, data: {eng:{ign: 0},gps:{speed: 0}}) }
      assert_nil @device.open_trip_event
      assert_nil @device.open_idle_event
      assert_event_state(@device.open_stop_event,first_reading, nil, nil, false)
    end
  end

  context 'creation flow' do
    should 'verify event creation sequences' do
      first_reading = nil
      assert_trip_idle_stop_differences(1, 1, 1) { first_reading = consider_next_reading(recorded_at: next_timestamp,speed: 0, data: {eng:{ign: 1},gps:{speed: 0}}, latitude: '36.1611893840757', longitude: '-86.81426620976718') }
      assert_equal EventTypes::EngineOn, first_reading.event_type
      assert_not_nil last_trip_event = @device.open_trip_event
      assert_not_nil last_idle_event = @device.open_idle_event
      assert_not_nil last_stop_event = @device.open_stop_event
      assert_equal 1, EventState::Base.open_trip_count

      last_reading = nil
      assert_trip_idle_stop_differences(0, 0, 0) { last_reading = consider_next_reading(recorded_at: next_timestamp(4 * 60), speed: 10, data: {eng:{ign: 1},gps:{speed: MPH_10}}) }
      assert_event_state(last_trip_event, first_reading, nil, nil, false)
      assert_event_state(last_idle_event, first_reading, last_reading, 4 * 60, false)
      assert_event_state(last_stop_event, first_reading, last_reading, 4 * 60, false)
      assert_equal EventTypes::EngineOn,first_reading.event_type
      assert_equal last_trip_event, @device.open_trip_event
      assert_nil @device.open_idle_event
      assert_nil @device.open_stop_event

      assert_trip_idle_stop_differences(0, 1, 1) { last_reading = consider_next_reading(recorded_at: next_timestamp(4 * 60),speed: 0, data: {eng:{ign: 1},gps:{speed: 0}}) }
      assert_nil last_reading.event_type
      assert_equal last_trip_event, @device.open_trip_event
      assert_not_nil last_idle_event = @device.open_idle_event
      assert_not_nil last_stop_event = @device.open_stop_event
      assert_event_state(last_trip_event, first_reading, nil, nil, false)
      assert_event_state(last_idle_event, last_reading, nil, nil, false)
      assert_event_state(last_stop_event, last_reading, nil, nil, false)

      assert_trip_idle_stop_differences(0, 0, 0) { consider_next_reading(recorded_at: next_timestamp(2 * 60),speed: 0, data: {eng:{ign: 1},gps:{speed: 0}}) }

      final_reading = nil
      assert_trip_idle_stop_differences(0, 0, 0) { final_reading = consider_next_reading(recorded_at: next_timestamp(2 * 60),speed: 0, data: {eng:{ign: 0},gps:{speed: 0}}) }
      assert_event_state(last_trip_event, first_reading, final_reading, 12 * 60, false)
      assert_event_state(last_idle_event, last_reading, final_reading, 4 * 60, false)
      assert_event_state(last_stop_event, last_reading, nil, nil, false)
      last_reading.reload
      assert_equal EventTypes::Idling, last_reading.event_type
      assert_equal EventTypes::EngineOff, final_reading.event_type
      assert_nil @device.open_trip_event
      assert_nil @device.open_idle_event
      assert_equal last_stop_event, @device.open_stop_event
      assert_equal 0, EventState::Base.open_trip_count

      assert_trip_idle_stop_differences(1, 1, 0) { consider_next_reading(recorded_at: next_timestamp(4 * 60),speed: 0, data: {eng:{ign: 1},gps:{speed: 0}}) }
      assert_event_state(last_stop_event, last_reading, nil, nil, false)

      assert_trip_idle_stop_differences(0, 0, 0) { final_reading = consider_next_reading(recorded_at: next_timestamp(4 * 60),speed: 10, data: {eng:{ign: 1},gps:{speed: MPH_10}}) }
      assert_event_state(last_stop_event, last_reading, final_reading, 12 * 60,false)
    end
  end


  context 'suspects flow' do
    should 'create suspects when duration is too small' do
      first_reading = nil
      assert_trip_idle_stop_differences(1, 1, 1) { first_reading = consider_next_reading(recorded_at: next_timestamp,speed: 0, data: {eng:{ign: 1},gps:{speed: 0}}, latitude: '36.1611893840757', longitude: '-86.81426620976718') }
      assert_equal EventTypes::EngineOn, first_reading.event_type
      assert_not_nil last_trip_event = @device.open_trip_event
      assert_not_nil last_idle_event = @device.open_idle_event
      assert_not_nil last_stop_event = @device.open_stop_event

      last_reading = nil
      assert_trip_idle_stop_differences(0, 0, 0) { last_reading = consider_next_reading(recorded_at: next_timestamp(2 * 60),speed: 10, data: {eng:{ign: 1},gps:{speed: MPH_10}}) }
      assert_event_state(last_trip_event, first_reading, nil, nil, false)
      assert_event_state(last_idle_event, first_reading, last_reading,2 * 60, true)
      assert_event_state(last_stop_event, first_reading, last_reading,2 * 60, true)
      assert_equal last_trip_event,@device.open_trip_event
      assert_nil @device.open_idle_event
      assert_nil @device.open_stop_event
      last_reading.reload
      assert_nil last_reading.event_type

      assert_trip_idle_stop_differences(0, 1, 1) { last_reading = consider_next_reading(recorded_at: next_timestamp(2 * 60),speed: 0, data: {eng:{ign: 1},gps:{speed: 0}}) }
      assert_equal last_trip_event, @device.open_trip_event
      assert_not_nil last_idle_event = @device.open_idle_event
      assert_not_nil last_stop_event = @device.open_stop_event
      assert_event_state(last_trip_event, first_reading, nil, nil, false)
      assert_event_state(last_idle_event, last_reading, nil, nil, false)
      assert_event_state(last_stop_event, last_reading, nil, nil, false)
      last_reading.reload
      assert_nil last_reading.event_type

      final_reading = nil
      assert_trip_idle_stop_differences(0, 0, 0) { final_reading = consider_next_reading(recorded_at: next_timestamp(2 * 60),speed: 0, data: {eng:{ign: 0},gps:{speed: 0}}) }
      assert_event_state(last_trip_event, first_reading, final_reading, 6 * 60, false)
      assert_event_state(last_idle_event, last_reading, final_reading, 2 * 60, true)
      assert_event_state(last_stop_event, last_reading, nil, nil, false)
      last_reading.reload
      assert_nil last_reading.event_type
      assert_equal EventTypes::EngineOff, final_reading.event_type
      assert_nil @device.open_trip_event
      assert_nil @device.open_idle_event
      assert_equal last_stop_event,@device.open_stop_event
    end
  end

  context 'trips flow' do
    should 'close and open a new trip if waiting too long between readings for an open trip' do
      first_reading = nil
      assert_trip_idle_stop_differences(1, 0, 0) { first_reading = consider_next_reading(recorded_at: next_timestamp,speed: 15, data: {eng:{ign: 1},gps:{speed: MPH_15}}, latitude: '36.1611893840757', longitude: '-86.81426620976718') }
      assert_equal EventTypes::EngineOn, first_reading.event_type
      assert_not_nil last_trip_event = @device.open_trip_event
      assert_nil @device.open_idle_event
      assert_nil @device.open_stop_event
      assert_event_state(last_trip_event,first_reading, nil, nil, false)

      last_reading = nil
      assert_trip_idle_stop_differences(0, 0, 0) { last_reading = consider_next_reading(recorded_at: next_timestamp(4 * 60),speed: 15, data: {eng:{ign: 1},gps:{speed: MPH_15}}) }
      assert_event_state(last_trip_event, first_reading, nil, nil, false)

      final_reading = nil
      assert_trip_idle_stop_differences(1, 0, 0) { final_reading = consider_next_reading(recorded_at: next_timestamp(EventState::Base::MAX_EXPIRED_SECONDS),speed: 15, data: {eng:{ign: 1},gps:{speed: MPH_15}}, latitude: '36.1611893840757', longitude: '-86.81426620976718') }
      assert_event_state(last_trip_event, first_reading, last_reading,4 * 60,false)
      assert_not_equal last_trip_event,@device.open_trip_event
      assert_event_state(@device.open_trip_event,final_reading, nil, nil, false)
    end

    should 'close and open a new stop if waiting too long between readings for an open trip' do
      first_reading = nil
      assert_trip_idle_stop_differences(1, 0, 0) { first_reading = consider_next_reading(recorded_at: next_timestamp,speed: 15, data: {eng:{ign: 1},gps:{speed: MPH_15}}, latitude: '36.1611893840757', longitude: '-86.81426620976718') }
      assert_equal EventTypes::EngineOn, first_reading.event_type
      assert_event_state(last_trip_event = @device.open_trip_event, first_reading, nil, nil, false)
      assert_nil @device.open_idle_event
      assert_nil @device.open_stop_event

      last_reading = nil
      assert_trip_idle_stop_differences(0, 0, 0) { last_reading = consider_next_reading(recorded_at: next_timestamp(4 * 60),speed: 15, data: {eng:{ign: 1},gps:{speed: MPH_15}}) }
      assert_event_state(last_trip_event, first_reading, nil, nil, false)

      final_reading = nil
      assert_trip_idle_stop_differences(0, 0, 1) { final_reading = consider_next_reading(recorded_at: next_timestamp(EventState::Base::MAX_EXPIRED_SECONDS),speed: 0, data: {eng:{ign: 0},gps:{speed: 0}}) }
      assert_event_state(last_trip_event, first_reading,last_reading, 4 * 60,false)
      assert_nil @device.open_trip_event
      assert_nil @device.open_idle_event
      assert_event_state(@device.open_stop_event, final_reading, nil, nil, false)
    end
  end

  context 'consider_transition' do
    should 'do nothing if same transition is attemped multiple times' do
      first_reading = nil
      assert_trip_idle_stop_differences(0, 0, 1) { first_reading = consider_next_reading(recorded_at: next_timestamp,speed: 0, data: {eng:{ign: 0},gps:{speed: 0}}) }
      assert_nil @device.open_trip_event
      assert_nil @device.open_idle_event
      assert_event_state(@device.open_stop_event, first_reading, nil, nil, false)
      assert_nil first_reading.event_type
      assert_equal first_reading, @state.previous_reading

      assert_trip_idle_stop_differences(0, 0, 0) { @state.consider_transition }
      assert_nil @device.open_trip_event
      assert_nil @device.open_idle_event
      assert_event_state(@device.open_stop_event, first_reading, nil, nil, false)
      assert_nil first_reading.event_type
      assert_equal first_reading, @state.previous_reading
    end
  end

  context 'open_trip_heap' do
    should 'be shared between multiple instances of state' do
      state2 = nil
      device2 = FactoryGirl.create(:active_device)
      EventState::Base.for_device(device2) { |state| state2 = state }
      assert_equal @state.class.open_trip_heap, state2.class.open_trip_heap

      first_reading = nil
      assert_trip_idle_stop_differences(1, 0, 0) { first_reading = consider_next_reading(recorded_at: next_timestamp(-2 * EventState::Base::MAX_EXPIRED_SECONDS),speed: 15, data: {eng:{ign: 1},gps:{speed: MPH_15}}, latitude: '36.1611893840757', longitude: '-86.81426620976718') }
      assert_not_nil last_trip_event = @device.open_trip_event
      assert_event_state(last_trip_event, first_reading, nil, nil, false)
      assert_equal 1, EventState::Base.open_trip_count
      assert_equal [first_reading.recorded_at.to_s(:db), @device.id.to_s], @state.open_trip_key.split('$')

      assert_equal @state.class.open_trip_heap, state2.class.open_trip_heap
    end
  end

  private

  def assert_event_state(target_event,start_reading,end_reading,duration,suspect)
    assert_not_nil target_event
    assert_special_equal start_reading, target_event.start_reading
    assert_coordinate_equality start_reading.latitude, target_event.start_latitude
    assert_coordinate_equality start_reading.longitude, target_event.start_longitude
    assert_special_equal start_reading.recorded_at.to_s(:db), target_event.started_at.to_s(:db)
    assert_special_equal duration, target_event.duration
    assert_special_equal !!suspect, !!target_event.suspect
    assert_special_equal end_reading, target_event.end_reading
    if end_reading
      assert_coordinate_equality end_reading.latitude, target_event.end_latitude
      assert_coordinate_equality end_reading.longitude, target_event.end_longitude
      assert_special_equal end_reading.recorded_at.to_s(:db), target_event.ended_at.to_s(:db)
    else
      assert_nil target_event.end_latitude
      assert_nil target_event.end_longitude
      assert_nil target_event.ended_at
    end
  end

  def assert_trip_idle_stop_differences(trip_difference,idle_difference,stop_difference,&block)
    assert_difference 'TripEvent.count', trip_difference do
      assert_difference 'IdleEvent.count', idle_difference do
        assert_difference 'StopEvent.count', stop_difference do
          block.call
        end
      end
    end
  end

  def consider_next_reading(attributes)
    reading = next_reading(attributes)
    @state.consider_transition
    reading
  end

  def next_reading(attributes)
    @device.last_reading = @device.readings.create!(attributes)
  end

  def next_timestamp(offset_seconds = 0)
    @next_timestamp += offset_seconds
  end

  def assert_coordinate_equality(target,actual)
    if target
      assert (target - actual).abs < 0.0000000001
    else
      assert_nil actual
    end
  end

  def assert_special_equal(exp,act)
    if exp.nil?
      assert_nil act
    else
      assert_equal exp,act
    end
  end

end
