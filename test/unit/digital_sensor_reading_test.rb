require 'test_helper'

class DigitalSensorReadingTest < ActiveSupport::TestCase
  context 'sensor_state' do
    context 'value is true' do
      setup do
        @digital_sensor_reading = FactoryGirl.build(:digital_sensor_reading, value: true)
      end

      should 'return high_label' do
        assert_equal 'High', @digital_sensor_reading.sensor_state
      end
    end
    context 'value is false' do
      setup do
        @digital_sensor_reading = FactoryGirl.build(:digital_sensor_reading, value: false)
      end

      should 'return low_label' do
        assert_equal 'Low', @digital_sensor_reading.sensor_state
      end
    end

    context 'description' do
      context 'value is true' do
        setup do
          @digital_sensor_reading = FactoryGirl.build(:digital_sensor_reading, value: true)
        end

        should 'return reading description' do
          assert_equal 'Digital Sensor (High)', @digital_sensor_reading.description
        end
      end
      context 'value is false' do
        setup do
          @digital_sensor_reading = FactoryGirl.build(:digital_sensor_reading, value: false)
        end

        should 'return reading description' do
          assert_equal 'Digital Sensor (Low)', @digital_sensor_reading.description
        end
      end
    end
  end
end
