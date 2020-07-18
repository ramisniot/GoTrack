require 'test_helper'

class Admin::DeviceHelperTest < ActionView::TestCase
  context 'digital_sensor_notification_type_option' do
    setup do
      @options = digital_sensor_notification_type_options(DigitalSensor.new(notification_type: DigitalSensor::NOTIFICATION_TYPES[:disable], address: 1))
    end

    should 'contain disable notification option' do
      assert_match /<option.*value=\"0\".*>Disabled<\/option>/, @options
    end

    should 'contain low_to_high notification option' do
      assert_match /<option.*value=\"1\".*>High to Low<\/option>/, @options
    end

    should 'contain high_to_low notification option' do
      assert_match /<option.*value=\"2\".*>Low to High<\/option>/, @options
    end

    should 'contain both notification option' do
      assert_match /<option.*value=\"3\".*>Both<\/option>/, @options
    end
  end
end
