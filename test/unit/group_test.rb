require 'test_helper'

class GroupTest < ActiveSupport::TestCase
  fixtures :groups, :users, :group_notifications, :devices, :readings

  def setup
    @group = Group.find(1)
  end

  def test_group_create
    group = Group.new
    group.name = nil
    assert_not group.save
    assert_equal 3, group.errors.count, group.errors.full_messages
  end

  def test_group_edit
    group = Group.find @group.id
    group.name = nil
    assert_not group.save
    assert_equal 1, group.errors.count, group.errors.full_messages
  end

  def test_group_delete
    group = Group.find @group.id
    assert group.destroy
  end

  def test_is_group_notification_true
    assert_equal true, @group.is_selected_for_notification(users(:dennis))
  end

  def test_is_group_notification_false
    assert_equal false, @group.is_selected_for_notification(users(:nick))
  end

  def test_devices
    assert_equal 2, @group.devices.length
  end

  def test_max_speed_change_calls_device_clear_cache
    assert_equal 2, @group.owned_devices.length

    @group.owned_devices.each{|device| device.expects(:clear_device_from_cache).returns(true)}

    @group.update_attributes(max_speed: 100)
  end

  def test_no_max_speed_change_does_not_call_device_clear_cache
    assert_equal 2, @group.owned_devices.length

    @group.owned_devices.each{|device| device.expects(:clear_device_from_cache).never}

    @group.update_attributes(name: 'no-speed-change')
  end

  test 'should return last reading from devices linked with a group' do
    device = Device.find(3)
    group = Group.find(2)
    assert_equal [device.last_gps_reading], group.get_readings_from_devices_for_rg
  end
end
