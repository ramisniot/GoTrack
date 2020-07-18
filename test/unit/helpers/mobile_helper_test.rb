require 'test_helper'

class MobileHelperTest < ActionView::TestCase
  context 'for devices with no last_gps_reading' do
    setup do
      @device = Device.new(name: 'Device', imei: 123, icon_id: 2)
    end

    should 'return the name and N/A when mobile_show_device is called' do
      assert_match /Device &nbsp;N\/A/, mobile_show_device(@device, true)
    end
  end

  context 'for devices with last_gps_reading' do
    setup do
      @device = Device.create!(name: 'Device', imei: 123, icon_id: 2, thing_token: '1dfs4sff44')
      @reading = Reading.create!(latitude: 1.2, longitude: 1.4, recorded_at: Time.now - 2.hours, device_id: @device.id)
      @device.update_attributes last_gps_reading_id: @reading.id
    end

    should 'return time ago in words for last_gps_reading and location when mobile_show_device is called' do
      html = mobile_show_device(@device, true).inspect
      assert_match /Center map on this device/, html
      assert_match /(about 2 hours ago)/, html
      assert_match /#{@reading.latitude}, #{@reading.longitude}/, html
    end
  end
end
