require 'test_helper'

class TelematicsStomperTest < ActiveSupport::TestCase
  # TODO revisit stompers
  # def setup
  #   ActionMailer::Base.delivery_method = :test
  #   ActionMailer::Base.perform_deliveries = true
  #   ActionMailer::Base.deliveries = []
  #
  #   NumerexLbs::EventState::Base.reset_cache
  #   @mock_time = Time.utc(2011, 1, 1, 1)
  #   Time.stubs(:now).returns(@mock_time)
  #   @mock_timestamp = Time.zone.now.strftime(Telematics::TIMESTAMP_FORMAT)
  #   @processor = TelematicsStomper.new
  #
  #   Device.delete_all
  #   Reading.delete_all
  # end
  #
  # context 'battery handling' do
  #   setup do
  #     NumerexLbs::EventState::Base.for_device(@device = FactoryGirl.create(:device, last_online_time: nil)) {}
  #   end
  #
  #   context 'standard battery voltage' do
  #     context 'obd_battery_voltage is present' do
  #       setup do
  #         @message = %[{
  #           "id": "d8886dff-72ef-46bb-b937-d4ca1785db55",
  #           "timestamp": "#{@mock_timestamp}",
  #           "type": "reading",
  #           "data": {
  #             "event_type": "ignition",
  #             "device_name": "#{@device.imei}",
  #             "event_timestamp": "#{@mock_timestamp}",
  #             "obd_battery_voltage": "13.2"
  #           },
  #           "headers": {}
  #         }]
  #       end
  #
  #       should 'fill reading.battery_voltage' do
  #         @processor.on_message(@message)
  #         assert_equal 13.2, @device.reload.last_reading.battery_voltage
  #       end
  #     end
  #
  #     context 'external_battery_voltage is present' do
  #       setup do
  #         @message = %[{
  #           "id": "d8886dff-72ef-46bb-b937-d4ca1785db55",
  #           "timestamp": "#{@mock_timestamp}",
  #           "type": "reading",
  #           "data": {
  #             "event_type": "ignition",
  #             "device_name": "#{@device.imei}",
  #             "event_timestamp": "#{@mock_timestamp}",
  #             "external_power_voltage": "13.2"
  #           },
  #           "headers": {}
  #         }]
  #       end
  #
  #       should 'fill reading.battery_voltage' do
  #         @processor.on_message(@message)
  #         assert_equal 13.2, @device.last_reading.battery_voltage
  #       end
  #     end
  #
  #     context 'there is no external battery voltage information' do
  #       setup do
  #         @message = %[{
  #           "id": "d8886dff-72ef-46bb-b937-d4ca1785db55",
  #           "timestamp": "#{@mock_timestamp}",
  #           "type": "reading",
  #           "data": {
  #             "event_type": "ignition",
  #             "device_name": "#{@device.imei}",
  #             "event_timestamp": "#{@mock_timestamp}"
  #           },
  #           "headers": {}
  #         }]
  #       end
  #
  #       should 'not fill reading.battery_voltage' do
  #         @processor.on_message(@message)
  #         assert_nil @device.last_reading.battery_voltage
  #       end
  #     end
  #   end
  # end
  #
  # context 'digital sensor readings' do
  #   setup do
  #     @device = FactoryGirl.create(:device, last_online_time: nil)
  #     NumerexLbs::EventState::Base.for_device(@device) {}
  #   end
  #
  #   should 'digital input message with information in event_type field' do
  #     @processor.on_message(%[{
  #       "timestamp":"#{@mock_timestamp}",
  #       "data":{
  #         "device_name":"#{@device.imei}",
  #         "event_timestamp":"#{@mock_timestamp}",
  #         "event_type":"input_high_01"
  #       },
  #       "headers":{},
  #       "id":"00000000-0000-0000-0000-000000000001",
  #       "type":"reading"}])
  #
  #     assert_nil @processor.last_message_error
  #
  #     reading = @device.last_reading
  #     assert_not_nil reading.digital_sensor_reading
  #     assert_equal 1, reading.digital_sensor_reading.digital_sensor.address
  #     assert_equal true, reading.digital_sensor_reading.value
  #   end
  # end
end
