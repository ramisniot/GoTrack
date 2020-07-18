require 'test_helper'

class ReadingsControllerTest < ActionController::TestCase
  # TODO revisit when there is a new Readings model...
  # include Devise::Test::ControllerHelpers
  #
  # fixtures :users, :accounts, :readings, :devices
  #
  # test "test_recent_json" do
  #   sign_in users(:dennis)
  #   get :recent, { format: 'json' }
  #   assert_response :success
  # end
  #
  # test "test_recent_xml" do
  #   sign_in users(:dennis)
  #   get :recent, { format: 'xml' }
  #   assert_response :success
  # end
  #
  # test "test_all_fails_without_auth" do
  #   get :all, { format: 'xml' }
  #   assert_response 401 #unauthorized
  # end
  #
  # test "test_last_fails_without_auth" do
  #   get :last, { format: 'xml' }
  #   assert_response 401 #unauthorized
  # end
  #
  # test "get_last_reading_info_for_device_returns_json" do
  #   sign_in users(:dennis)
  #   get :get_last_reading_info_for_device, id: devices(:device1).id
  #   assert :success
  # end
  #
  # context 'public' do
  #   setup do
  #     sign_in users(:dennis)
  #
  #     device = FactoryGirl.create(:device, account: users(:dennis).account)
  #
  #     digital_sensor_1 = FactoryGirl.create(:digital_sensor, device: device, address: 1)
  #
  #     reading = FactoryGirl.create(
  #       :reading,
  #       gateway_event_type: 'input_high_1',
  #       event_type: EventTypes::AssetLowToHigh,
  #       recorded_at: Time.now,
  #       device: device,
  #       digital_sensor_reading: FactoryGirl.create(
  #         :digital_sensor_reading,
  #         digital_sensor: digital_sensor_1,
  #         value: true
  #       )
  #     )
  #     device.update_attribute(:last_gps_reading, reading)
  #
  #     get :public, { format: 'xml', id: users(:dennis).account.id }
  #   end
  #
  #   should 'have event type information' do
  #     assert_match /<item>.*<eventType>Digital Sensor \(High\)<\/eventType>.*<\/item>/m, response.body
  #   end
  # end
end
