require 'test_helper'

class DeviceProfileTest < ActiveSupport::TestCase
  fixtures :device_profiles, :devices

  def setup
    @dp = DeviceProfile.new(name: 'Profile Name', speeds: true, stops: true, idles: true, watch_gpio1: true, watch_gpio2: true, gpio1_labels: "GPIO1\t0\t12\tLowNotice\tHighNotice\tLowStatus\tHighStatus", gpio2_labels: "GPIO2\t0\t12\tLowNotice\tHighNotice\tLowStatus\tHighStatus", trips: true)
  end

  test 'gpio1_name should return its name' do
    assert_equal 'GPIO1', @dp.gpio1_name
  end

  test 'gpio2_name should return its name' do
    assert_equal 'GPIO2', @dp.gpio2_name
  end

  test 'gpio1_low_value should return its value' do
    assert_equal '0', @dp.gpio1_low_value
  end

  test 'gpio2_low_value should return its value' do
    assert_equal '0', @dp.gpio2_low_value
  end

  test 'gpio1_high_value should return its value' do
    assert_equal '12', @dp.gpio1_high_value
  end

  test 'gpio2_high_value should return its value' do
    assert_equal '12', @dp.gpio2_high_value
  end

  test 'gpio1_low_notice should return its value' do
    assert_equal 'LowNotice', @dp.gpio1_low_notice
  end

  test 'gpio2_low_notice should return its value' do
    assert_equal 'LowNotice', @dp.gpio2_low_notice
  end

  test 'gpio1_high_notice should return its value' do
    assert_equal 'HighNotice', @dp.gpio1_high_notice
  end

  test 'gpio2_high_notice should return its value' do
    assert_equal 'HighNotice', @dp.gpio2_high_notice
  end

  test 'gpio1_low_status should return its value' do
    assert_equal 'LowStatus', @dp.gpio1_low_status
  end

  test 'gpio2_low_status should return its value' do
    assert_equal 'LowStatus', @dp.gpio2_low_status
  end

  test 'gpio1_high_status should return its value' do
    assert_equal 'HighStatus', @dp.gpio1_high_status
  end

  test 'gpio2_high_status should return its value' do
    assert_equal 'HighStatus', @dp.gpio2_high_status
  end
end
