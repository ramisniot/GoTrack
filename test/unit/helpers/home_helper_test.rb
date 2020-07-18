require 'test_helper'

class HomeHelperTest < ActionView::TestCase
  include ApplicationHelper

  context 'show_device method' do
    setup do
      @device = FactoryGirl.create(:device, name: 'Device')
    end

    context 'for devices with last_gps_reading' do
      setup do
        reading = FactoryGirl.create(:reading, device: @device)
        @device.last_gps_reading_id = reading.id
      end

      should 'return properly html for @device' do
        assert_match /Device/, show_device(@device, false)
      end

      should 'return properly html for @device with link' do
        assert_match /Device/, show_device(@device, true)
        assert_match /javascript:focusOnAndFollow/, show_device(@device, true)
      end
    end

    context 'for devices without last_gps_reading' do
      should 'return properly html for @device' do
        assert_match /Device/, show_device(@device, false)
        assert_match /N\/A/, show_device(@device, false)
      end

      should 'return properly html without link for @device' do
        assert_match /Device/, show_device(@device, true)
        assert_match /N\/A/, show_device(@device, true)
      end
    end

    context 'for request_location as true and current_user as not read only' do
      setup do
        @device.stubs(request_location?: true)

        @user = User.new
        @user.stubs(is_read_only?: false)
      end

      should 'return a string with Find Now inside' do
        assert_match 'Find Now', show_device(@device, true)
      end
    end
  end

  context 'show_device_location method' do
    setup do
      @device = FactoryGirl.create(:device, name: 'Device')
      reading = FactoryGirl.create(:reading, device: @device)
      @device.last_gps_reading_id = reading.id
    end

    should 'return same as show_device with show_location as true' do
      assert_match /Device/, show_device_location(@device)
      assert_match /Standard Location/, show_device_location(@device)
      assert_match /Standard Date and Time/, show_device_location(@device)
      assert_match /javascript:focusOnAndFollow/, show_device_location(@device)
    end
  end

  context 'show_device_status method' do
    setup do
      @device = FactoryGirl.create(:device, name: 'Device')
      reading = FactoryGirl.create(:reading, device: @device)
      @device.last_gps_reading_id = reading.id
    end

    should 'return same as show_device with show_location as false' do
      assert_match /Device/, show_device_status(@device)
      assert_match /Standard Location/, show_device_status(@device)
      assert_match /Standard Date and Time/, show_device_status(@device)
    end
  end

  context 'show_statistics method' do
    setup do
      @device = FactoryGirl.create(:device, name: 'Device')
    end

    context 'for devices with last_gps_reading' do
      setup do
        reading = FactoryGirl.create(:reading, device: @device)
        @device.last_gps_reading_id = reading.id
      end

      should 'return information of device, link and statistics' do
        assert_match /Device/, show_statistics(@device)
        assert_match /22.62/, show_statistics(@device)
        assert_match /javascript:focusOnAndFollow/, show_statistics(@device)
        assert_match /Center map on this device/, show_statistics(@device)
      end
    end

    context 'for devices without last_gps_reading' do
      should 'return information of device, link and statistics' do
        assert_match /Device/, show_statistics(@device)
        assert_match /22.62/, show_statistics(@device)
        assert_match /View device details/, show_statistics(@device)
      end
    end
  end

  context 'entities method' do
    should 'return same string if is called with a string without "/" inside' do
      assert_equal 'string', entities('string')
    end
  end

  context 'devices_in_group_and_dispatchable' do
    setup do
      account = FactoryGirl.create(:account)
      @device = FactoryGirl.create(:device, account: account)
      device2 = FactoryGirl.create(:device, account: account)
      FactoryGirl.create(:device, group: nil, account: account)
      group = FactoryGirl.create(:group, image_value: 3, devices: [@device, device2], account: account)

      dispatchable_devices = [@device.id]
      @result = devices_in_group_and_dispatchable(group.reload, dispatchable_devices)
    end

    should 'return @device' do
      assert @result.to_a.map(&:id).include?(@device.id)
    end

    should 'return only one device' do
      assert_equal 1, @result.size
    end
  end

  private

  def standard_location(param1, param2, param3)
    'Standard Location'
  end

  def standard_date_and_time(param1)
    'Standard Date and Time'
  end

  def current_user
    @user
  end
end
