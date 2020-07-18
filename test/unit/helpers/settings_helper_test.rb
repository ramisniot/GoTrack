require 'test_helper'

class SettingsHelperTest < ActionView::TestCase
  context 'notification_type_description' do
    should 'return `Device goes offline` for :offline' do
      assert_equal 'Device goes offline', notification_type_description(:offline)
    end

    should 'return `Idling` for :idling' do
      assert_equal 'Idling', notification_type_description(:idling)
    end

    should 'return `Sensor Input` for :sensor' do
      assert_equal 'Sensor Input', notification_type_description(:sensor)
    end

    should 'return `Speed` for :speed' do
      assert_equal 'Speed', notification_type_description(:speed)
    end

    should 'return `Geofence` for :geofence' do
      assert_equal 'Geofence', notification_type_description(:geofence)
    end

    should 'return `General-purpose input/output` for :gpio' do
      assert_equal 'General-purpose input/output', notification_type_description(:gpio)
    end

    should 'return `First movement` for :first_movement' do
      assert_equal 'First movement', notification_type_description(:first_movement)
    end

    should 'return `Startup` for :startup' do
      assert_equal 'Startup', notification_type_description(:startup)
    end

    should 'return `GPS unit power` for :gps_unit_power' do
      assert_equal 'GPS unit power', notification_type_description(:gps_unit_power)
    end

    should 'return `Maintenance` for :maintenance' do
      assert_equal 'Maintenance', notification_type_description(:maintenance)
    end
  end
end
