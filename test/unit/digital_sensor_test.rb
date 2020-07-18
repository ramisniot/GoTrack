require 'test_helper'

class DigitalSensorTest < ActiveSupport::TestCase
  context 'build_sensor'  do
    context 'when template is nil' do
      setup do
        @digital_sensor = DigitalSensor.build_sensor(1, nil)
      end

      should 'return a default digital sensor' do
        assert_equal DigitalSensor, @digital_sensor.class
        assert_equal 'Digital Sensor 1', @digital_sensor.name
        assert_equal 'High', @digital_sensor.high_label
        assert_equal 'Low', @digital_sensor.low_label
        assert_equal 1, @digital_sensor.address
        assert_equal DigitalSensor::NOTIFICATION_TYPES[:disabled], @digital_sensor.notification_type
      end
    end

    context 'when template is not nil' do
      setup do
        @template_sensor = FactoryGirl.build(:sensor_template)
        @digital_sensor = DigitalSensor.build_sensor(1, @template_sensor)
      end

      should 'return a sensor with template data' do
        assert_equal DigitalSensor, @digital_sensor.class
        assert_equal 'Sensor Template', @digital_sensor.name
        assert_equal 'Low', @digital_sensor.low_label
        assert_equal 'High', @digital_sensor.high_label
        assert_equal 1, @digital_sensor.address
        assert_equal DigitalSensor::NOTIFICATION_TYPES[:disabled], @digital_sensor.notification_type
      end
    end
  end

  context 'high_to_low_notifications?' do
    context 'when digital sensor notification is equal to disabled' do
      setup do
        @digital_sensor = DigitalSensor.new(notification_type: DigitalSensor::NOTIFICATION_TYPES[:disabled])
      end
      should 'return false' do
        assert_not @digital_sensor.high_to_low_notifications?
      end
    end

    context 'when digital sensor notification is equal to high_to_low' do
      setup do
        @digital_sensor = DigitalSensor.new(notification_type: DigitalSensor::NOTIFICATION_TYPES[:high_to_low])
      end
      should 'return true' do
        assert @digital_sensor.high_to_low_notifications?
      end
    end

    context 'when digital sensor notification is equal to low_to_high' do
      setup do
        @digital_sensor = DigitalSensor.new(notification_type: DigitalSensor::NOTIFICATION_TYPES[:low_to_high])
      end
      should 'return false' do
        assert_not @digital_sensor.high_to_low_notifications?
      end
    end

    context 'when digital sensor notifications is equal to both' do
      setup do
        @digital_sensor = DigitalSensor.new(notification_type: DigitalSensor::NOTIFICATION_TYPES[:both])
      end
      should 'return true' do
        assert @digital_sensor.high_to_low_notifications?
      end
    end
  end

  context 'low_to_high_notifications?' do
    context 'when digital sensor notification is equal to disabled' do
      setup do
        @digital_sensor = DigitalSensor.new(notification_type: DigitalSensor::NOTIFICATION_TYPES[:disabled])
      end
      should 'return false' do
        assert_not @digital_sensor.low_to_high_notifications?
      end
    end

    context 'when digital sensor notification is equal to high_to_low' do
      setup do
        @digital_sensor = DigitalSensor.new(notification_type: DigitalSensor::NOTIFICATION_TYPES[:high_to_low])
      end
      should 'return false' do
        assert_not @digital_sensor.low_to_high_notifications?
      end
    end

    context 'when digital sensor notification is equal to low_to_high' do
      setup do
        @digital_sensor = DigitalSensor.new(notification_type: DigitalSensor::NOTIFICATION_TYPES[:low_to_high])
      end
      should 'return true' do
        assert @digital_sensor.low_to_high_notifications?
      end
    end

    context 'when digital sensor notifications is equal to both' do
      setup do
        @digital_sensor = DigitalSensor.new(notification_type: DigitalSensor::NOTIFICATION_TYPES[:both])
      end
      should 'return true' do
        assert @digital_sensor.low_to_high_notifications?
      end
    end
  end

  context 'should_notify?' do
    setup do
      @digital_sensor = FactoryGirl.build(:digital_sensor)
    end

    context 'value_change? returns true' do
      setup do
        @digital_sensor.stubs(:value_change?).returns(true)
      end

      context 'low_to_high_notification? returns true' do
        setup do
          @digital_sensor.stubs(:low_to_high_notifications?).returns(true)
        end
        context 'high_to_low_notification? returns true' do
          setup do
            @digital_sensor.stubs(:high_to_low_notifications?).returns(true)
          end

          should 'return true if event_type is EventTypes::AssetLowToHigh' do
            assert @digital_sensor.should_notify?(EventTypes::AssetLowToHigh, true)
          end

          should 'return true if event_type is EventTypes::AssetHighToLow' do
            assert @digital_sensor.should_notify?(EventTypes::AssetHighToLow, true)
          end
        end

        context 'high_to_low_notification? returns false' do
          setup do
            @digital_sensor.stubs(:high_to_low_notifications?).returns(false)
          end

          should 'return true if event_type is EventTypes::AssetLowToHigh' do
            assert @digital_sensor.should_notify?(EventTypes::AssetLowToHigh, true)
          end

          should 'return false if event_type is EventTypes::AssetHighToLow' do
            assert_not @digital_sensor.should_notify?(EventTypes::AssetHighToLow, true)
          end
        end
      end

      context 'low_to_high_notification? returns false' do
        setup do
          @digital_sensor.stubs(:low_to_high_notifications?).returns(false)
        end
        context 'high_to_low_notification? returns true' do
          setup do
            @digital_sensor.stubs(:high_to_low_notifications?).returns(true)
          end

          should 'return false if event_type is EventTypes::AssetLowToHigh' do
            assert_not @digital_sensor.should_notify?(EventTypes::AssetLowToHigh, true)
          end

          should 'return true if event_type is EventTypes::AssetHighToLow' do
            assert @digital_sensor.should_notify?(EventTypes::AssetHighToLow, true)
          end
        end

        context 'high_to_low_notification? returns false' do
          setup do
            @digital_sensor.stubs(:high_to_low_notifications?).returns(false)
          end

          should 'return false if event_type is EventTypes::AssetLowToHigh' do
            assert_not @digital_sensor.should_notify?(EventTypes::AssetLowToHigh, true)
          end

          should 'return false if event_type is EventTypes::AssetHighToLow' do
            assert_not @digital_sensor.should_notify?(EventTypes::AssetHighToLow, true)
          end
        end
      end
    end

    context 'value_change? returns false' do
      setup do
        @digital_sensor.stubs(:value_change?).returns(false)
      end

      context 'low_to_high_notification? returns true' do
        setup do
          @digital_sensor.stubs(:low_to_high_notifications?).returns(true)
        end
        context 'high_to_low_notification? returns true' do
          setup do
            @digital_sensor.stubs(:high_to_low_notifications?).returns(true)
          end

          should 'return false if event_type is EventTypes::AssetLowToHigh' do
            refute @digital_sensor.should_notify?(EventTypes::AssetLowToHigh, true)
          end

          should 'return false if event_type is EventTypes::AssetHighToLow' do
            refute @digital_sensor.should_notify?(EventTypes::AssetHighToLow, true)
          end
        end

        context 'high_to_low_notification? returns false' do
          setup do
            @digital_sensor.stubs(:high_to_low_notifications?).returns(false)
          end

          should 'return false if event_type is EventTypes::AssetLowToHigh' do
            refute @digital_sensor.should_notify?(EventTypes::AssetLowToHigh, true)
          end

          should 'return false if event_type is EventTypes::AssetHighToLow' do
            refute @digital_sensor.should_notify?(EventTypes::AssetHighToLow, true)
          end
        end
      end

      context 'low_to_high_notification? returns false' do
        setup do
          @digital_sensor.stubs(:low_to_high_notifications?).returns(false)
        end
        context 'high_to_low_notification? returns true' do
          setup do
            @digital_sensor.stubs(:high_to_low_notifications?).returns(true)
          end

          should 'return false if event_type is EventTypes::AssetLowToHigh' do
            refute @digital_sensor.should_notify?(EventTypes::AssetLowToHigh, true)
          end

          should 'return false if event_type is EventTypes::AssetHighToLow' do
            refute @digital_sensor.should_notify?(EventTypes::AssetHighToLow, true)
          end
        end

        context 'high_to_low_notification? returns false' do
          setup do
            @digital_sensor.stubs(:high_to_low_notifications?).returns(false)
          end

          should 'return false if event_type is EventTypes::AssetLowToHigh' do
            refute @digital_sensor.should_notify?(EventTypes::AssetLowToHigh, true)
          end

          should 'return false if event_type is EventTypes::AssetHighToLow' do
            refute @digital_sensor.should_notify?(EventTypes::AssetHighToLow, true)
          end
        end
      end
    end
  end

  context 'value_change?' do
    context 'digital sensor with digital sensors readings' do
      setup do
        digital_sensor_reading = FactoryGirl.build(:digital_sensor_reading, value: true)
        @digital_sensor = FactoryGirl.build(:digital_sensor, last_digital_sensor_reading: digital_sensor_reading)
      end

      context 'last value is equal to the given value' do
        should 'return false' do
          refute @digital_sensor.value_change?(true)
        end
      end

      context 'last value is not equal to the given value' do
        should 'return true' do
          assert @digital_sensor.value_change?(false)
        end
      end
    end

    context 'digital sensor without digital sensor readings' do
      setup do
        @digital_sensor = FactoryGirl.build(:digital_sensor)
      end

      context 'new value is equal to true' do
        should 'return true' do
          assert @digital_sensor.value_change?(true)
        end
      end

      context 'new value is equal to false' do
        should 'return true' do
          assert @digital_sensor.value_change?(false)
        end
      end
    end
  end
end
