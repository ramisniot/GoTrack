require 'test_helper'

class EventState::BaseTest < ActiveSupport::TestCase

  def setup
    EventState::Base.reset_cache
    EventState::Base.for_device(@device = FactoryGirl.create(:inactive_device)) {|state| @state = state} # NOTE - this technique is dangerous in a real multi-threaded situation
  end

  context 'for_thing_token' do
    should 'add entry to @@state_cache for thing_token' do
      EventState::Base.forget_device(@device)

      assert_state_cache_difference(+1) do
        EventState::Base.for_thing_token(@device.thing_token, @device) { }
      end
    end

    should 'not add an entry to @@state_cache if the thing_token of the device is already in the cache' do
      assert_state_cache_difference(0) do
        EventState::Base.for_thing_token(@device.thing_token) { |state| assert_equal @state, state }
      end
    end

    should 'raise an exception if it is called without thing_token' do
      assert_raise do
        EventState::Base.for_thing_token(nil) { |state| assert_equal @state, state }
      end
    end

    should 'call unlock if the state is locked' do
      @state.expects(:unlock).at_least(1)
      EventState::Base.for_thing_token(@device.thing_token) { |state| assert_equal @state, state }
    end
  end

  context 'for_device' do
    should 'add an entry to @@state_cache' do
      EventState::Base.reset_cache
      assert_state_cache_difference(+1) do
        EventState::Base.for_device(@device = FactoryGirl.create(:inactive_device)) {|state| @state = state}
      end
    end
  end

  context 'exists_for_thing_token' do
    should 'return true if @@state_cache already has an entry for the given thing_token' do
      assert EventState::Base.exists_for_thing_token?(@device.thing_token)
    end

    should 'return false if @@state_cache does not have an entry for the given thing_token' do
      assert !EventState::Base.exists_for_thing_token?('12345')
    end
  end

  context 'forget_device' do
    should 'remove the device from @@state_cache if the thing_token is present' do
      assert_state_cache_difference(-1) do
        EventState::Base.forget_device(@device)
      end
    end
    should 'not remove the device from @@state_cache if the thing_token is not present' do
      EventState::Base.forget_device(@device)

      assert_state_cache_difference(0) do
        EventState::Base.forget_device(@device)
      end
    end
  end

  context 'reset_cache' do
    should 'clear all structures' do
      @device.expects(:save).at_least(1)
      assert_state_cache_difference(-1) do
        EventState::Base.reset_cache
      end
      assert_equal Hash.new, EventState::Base.class_eval('@@state_cache')
      assert_nil EventState::Base.class_eval('@@open_trip_heap')
    end
  end

  context 'initialize' do
    should 'set @device' do
      assert_equal @state.device, @device
    end

    should 'set @instance_mutex' do
      assert @state.instance_eval('@instance_mutex').is_a?(Mutex)
    end

    should 'set @previous_reading' do
      state2 = nil
      device = FactoryGirl.create(:active_device)
      next_timestamp = Time.now - 2.hours
      device.last_reading = device.readings.create!(recorded_at: next_timestamp, ignition: true, speed: 15, latitude: '36.1611893840757', longitude: '-86.81426620976718')

      assert_state_cache_difference(+1) do
        EventState::Base.for_device(device) { |state| state2 = state }
      end
      assert_not_nil device.last_reading
      assert_equal state2.previous_reading, device.last_reading
    end
  end

  context 'locked?' do
    should 'be delegated to @instance_mutex' do
      @state.instance_eval('@instance_mutex').expects(:locked?).at_least(1)
      @state.locked?
    end
  end

  context 'lock' do
    should 'be delegated to @instance_mutex' do
      @state.instance_eval('@instance_mutex').expects(:lock).returns(false)
      @state.lock
    end
  end

  context 'unlock' do
    should 'be delegated to @instance_mutex' do
      @state.instance_eval('@instance_mutex').expects(:unlock).returns(true)
      @state.unlock
    end
  end

  private

  def assert_state_cache_difference(difference, &block)
    assert_difference("EventState::Base.class_eval('@@state_cache.count')", difference) do
      block.call
    end
  end

end
