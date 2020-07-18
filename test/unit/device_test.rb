require 'test_helper'

class DeviceTest < ActiveSupport::TestCase
  fixtures :devices, :accounts, :geofences, :device_profiles, :readings, :stop_events, :idle_events

  should validate_length_of(:name).is_at_most(Device::MAX_LENGTH[:name])
  should validate_length_of(:imei).is_at_most(Device::MAX_LENGTH[:imei])
  should validate_length_of(:phone_number).is_at_most(Device::MAX_LENGTH[:phone_number])

  # New online threshold is too large for this to work
  def test_last_offline_notification
    assert_equal true, devices(:device1).online?, "device 1 should be online"
    assert_equal false, devices(:device2).online?, "device 2 should be offline"
    assert_equal false, devices(:device3).online?, "device 3 should be offline (devices(:device3) = #{devices(:device3).inspect})"
    assert_equal true, devices(:device4).online?, "device 4 should be online"
  end

  test 'notify_on_working_hours?' do
    d = Device.new
    d.account = Account.new
    d.account.expects(:notify_on_working_hours?).once
    d.notify_on_working_hours?
  end

  test 'users to notify no account' do
    assert Device.new.users_to_notify.empty?
  end

  test 'users to notify with account' do
    d = Device.new
    d.account = Account.new
    d.account.expects(:users).returns([1, 2, 3]).once
    assert_equal [1, 2, 3], d.users_to_notify
  end

  #TODO revisit gateways
  # def test_logical_device_for_gateway_device
  #   assert_equal 'Not Found', Device.logical_device_for_gateway_device(Xirgo::Device.last).name
  # end
  # def test_friendly_name_for_gateway_device
  #   assert_equal 'Not Found', Device.friendly_name_for_gateway_device(Xirgo::Device.last)
  #   assert_equal 'Unassigned', Device.friendly_name_for_gateway_device(nil)
  # end

  context 'device with last gps reading' do
    setup do
      @device = FactoryGirl.create(:device)
      @reading = FactoryGirl.create(:reading, device: @device)
      @device.last_gps_reading = @reading
    end

    should 'return latitude of its last_gps_reading' do
      assert_equal @reading.latitude, @device.latitude
    end

    should 'return longitude of its last_gps_reading' do
      assert_equal @reading.longitude, @device.longitude
    end

    should 'return speed of its last_gps_reading' do
      assert_equal @reading.speed, @device.speed
    end

    should 'return direction of its last_gps_reading' do
      assert_equal @reading.direction, @device.direction
    end

    should 'return address of its last_gps_reading' do
      assert_equal @reading.short_address, @device.address
    end

    should 'defer deletion of history' do
      RabbitMessageProducer.expects(:publish_clear_device_history).once
      assert_equal 1, @device.readings.count
      assert @device.clear_history
      assert_nil @device.last_gps_reading
      assert_equal 1, @device.readings.count
    end

    should 'be cleared with history' do
      RabbitMessageProducer.expects(:publish_clear_device_history).never
      assert_equal 1, @device.readings.count
      assert @device.clear_history(false)
      assert_nil @device.last_gps_reading
      assert_equal 0, @device.readings.count
    end
  end

  context 'device without last gps reading' do
    setup do
      @device = FactoryGirl.build(:device)
    end

    should 'return nil for its latitude' do
      assert_nil@device.latitude
    end

    should 'return nil for its longitude' do
      assert_nil@device.longitude
    end

    should 'return nil for its speed' do
      assert_nil@device.speed
    end

    should 'return nil for its direction' do
      assert_nil@device.direction
    end

    should 'return address of its last_gps_reading' do
      assert_equal '', @device.address
    end
  end

  test 'per page should return 25' do
    assert_equal 25, Device.per_page
  end

  test 'search for devices' do
    Device.delete_all
    FactoryGirl.create(:device,name: 'TEST')
    assert Device.search_for_devices({ name_eq: 'TEST' }, 1).include?(Device.last)
  end

  context 'dt' do
    setup do
      @device = Device.new(FactoryGirl.attributes_for(:device))
    end

    should 'return an empty string if device does not have last gps reading' do
      assert_equal '', @device.dt
    end

    should 'return datetime if device has last gps reading' do
      r = Reading.new(recorded_at: '2013-01-04 11:05:49 -0300')
      @device.last_gps_reading = r

      user = User.create(first_name: 'Gab', last_name: 'Test', email: 'm@moove-it.com')
      user.stubs(:time_zone).returns('UTC')
      user.roles = [:view_only]
      @device.stubs(current_user: user)

      assert_equal '04-Jan-2013 02:05 PM', @device.dt
    end
  end

  context 'after_update callbacks' do
    setup do
      @device = FactoryGirl.create(:device)
    end
    
    should 'emit event to clear device from devices cache if name changes' do
      RabbitMessageProducer.expects(:publish_forget_device).with(@device.thing_token)
      @device.update_attributes({ name: 'new name' })
    end
    
    should 'not emit event to clear device from devices cache if name does not change' do
      RabbitMessageProducer.expects(:publish_forget_device).never
      @device.update_attributes({ phone_number: '1111' })
    end
  end

  context '#full_dt' do
    setup do
      @device = FactoryGirl.build(:device)
    end

    context 'when the device doesn\'t have a last gps reading' do
      should 'return an empty string' do
        assert_equal '', @device.full_dt
      end
    end

    context 'when the device has a last gps reading' do
      should 'return the last gps reading recorded_at in the appropiate format' do
        last_gps_reading = FactoryGirl.build(:reading, recorded_at: '2017-11-03 10:54:00 -0300')
        @device.last_gps_reading = last_gps_reading

        user = FactoryGirl.create(:user)
        user.stubs(:time_zone).returns('UTC')
        user.roles = [:view_only]
        @device.stubs(current_user: user)

        assert_equal '03-Nov-2017 01:54 PM', @device.full_dt
      end
    end
  end

  context 'distance_to' do
    setup do
      @device = Device.new(FactoryGirl.attributes_for(:device))
      @reading = Reading.new(FactoryGirl.attributes_for(:reading))
      @device.last_gps_reading = @reading
    end

    should 'return distance from the last_gps_reading to lat/lng as param' do
      assert_equal 13.831108817178317, @device.distance_to('1.2,1.2')
    end
  end

  context 'max_speed' do
    setup do
      @device = Device.new(FactoryGirl.attributes_for(:device))
    end

    should 'should return nil if device has no group and account' do
      assert_nil @device.max_speed
    end

    context 'for account with max speed' do
      setup do
        @a = FactoryGirl.build(:account)
        @a.max_speed = 90
        @a.save
      end

      should 'return max speed for account if have group and max_speed is not set' do
        @g = Group.create(name: 'Test group', image_value: 2, account_id: @a.id, max_speed: 80)
        @device.group_id = @g.id

        assert_equal 80, @device.max_speed
      end
    end
  end

  context 'tests for gateway location' do
    setup do
      @device = Device.new(FactoryGirl.attributes_for(:device))
    end

    should 'return nil due to device do not have gateway_device for request_location function' do
      assert_nil @device.request_location?
    end

    should 'return nil due to device do not have gateway_device for last_location_request function' do
      assert_nil @device.last_location_request
    end

    should 'return nil due to device do not have gateway_device for submit_location_request function' do
      assert_nil @device.submit_location_request
    end
  end

  context 'has_movement_alert_for_user' do
    setup do
      @device = Device.new(FactoryGirl.attributes_for(:device))
    end

    should 'return false if called with nil param' do
      assert_not @device.has_movement_alert_for_user(nil)
    end

    should 'return false if not exists any movement alert' do
      user = User.create(FactoryGirl.attributes_for(:user))
      assert_not @device.has_movement_alert_for_user(user)
    end
  end

  context 'has_movement_alert_for_current_user' do
    setup do
      @device = Device.new(FactoryGirl.attributes_for(:device))
    end

    should 'return nil if current_user is not set' do
      assert_nil @device.has_movement_alert_for_current_user
    end
  end

  context 'geofence method' do
    setup do
      @device = Device.new(FactoryGirl.attributes_for(:device))
    end

    should 'return nil if device does not have last_gps_reading' do
      assert_nil @device.geofence
    end

    context 'if device have last_gps_reading' do
      setup do
        @reading = Reading.create(recorded_at: Time.now, geofence_event_type: 'enter')
        @device.last_gps_reading = @reading
        @device.save
      end

      should 'return nil if last_gps_reading does not have geofence' do
        assert_nil @device.geofence
      end

      should 'return nil if last_gps_reading has geofence_id < 0' do
        @reading.geofence_id = -1
        assert_nil @device.geofence
      end

      should 'return geofence name' do
        geofence = Geofence.create(name: 'Geof1', latitude: 1.2, longitude: 1.4, radius: 2.0)
        @reading.geofence_id = geofence.id
        @reading.save

        assert_equal 'entering Geof1', @device.geofence
      end
    end
  end

  context 'helper standard location method' do
    setup do
      @device =FactoryGirl.create(:device)
    end

    should 'return GPS Not Available if last_gps_reading is nil' do
      assert_equal 'GPS Not Available', @device.helper_standard_location
    end

    context 'for device with last_gps_reading' do
      setup do
        @reading = Reading.create(recorded_at: Time.now, latitude: 1.2, longitude: 1.4)
        @device.stubs(last_gps_reading: @reading)
      end

      should 'return reading short address if reading does not have a geofence' do
        assert_match 'Getting Address...', @device.helper_standard_location
      end

      should 'return reading short address if reading does not have a geofence and current_user is read only' do
        @user = User.create(first_name: 'Gab', last_name: 'Test', email: 'm@moove-it.com')
        @user.roles = [:view_only]
        @device.stubs(current_user: @user)

        assert_match 'Getting Address...', @device.helper_standard_location
      end

      should 'return the name of geofence if last_gps_reading has geofence and current_user is superadmin' do
        @user = User.create(first_name: 'Gab', last_name: 'Test', email: 'm@moove-it.com')
        @user.roles = [:superadmin]
        @device.stubs(current_user: @user)

        geofence = Geofence.create(name: 'Geof1', latitude: 1.2, longitude: 1.4, radius: 2.0)
        @reading.stubs(geofence: geofence)

        assert_match /View this location/, @device.helper_standard_location
        assert_match /Getting Address.../, @device.helper_standard_location
      end

      should 'return complete geofence information and link to add location if does not have geofence' do
        @user = User.create(first_name: 'Gab', last_name: 'Test', email: 'm@moove-it.com')
        @user.roles = [:superadmin]
        @device.stubs(current_user: @user)

        assert_match /Add a new location/, @device.helper_standard_location
        assert_match /#{@reading.short_address}/, @device.helper_standard_location
      end
    end
  end

  context 'update_mileage!' do
    setup do
      @device = Device.create(FactoryGirl.attributes_for(:device))
    end

    should 'restart mileage if is < 0 and return nil' do
      assert_nil @device.update_mileage!
      assert_equal 0, @device.total_mileage
    end
  end

  context 'update_mileage_tasks' do
    context 'without tasks' do
      should 'not call remaining miles on any task' do
        Maintenance.any_instance.expects(:remaining_miles).never
        Device.new.update_mileage_tasks
      end
    end
    context 'with tasks' do
      setup do
        @device = devices(:device1)
        Maintenance.delete_all
        @device.maintenances.create type_task: Maintenance::MILEAGE_TYPE, description_task: 'test', mileage: 5000
      end

      should 'call remaining miles when notified_at is nil' do
        Maintenance.any_instance.expects(:remaining_miles).once
        @device.update_mileage_tasks
      end

      should 'call remaining_miles when notified_at is over a day old' do
        @device.maintenances.first.update_attributes(notified_at: (1.day + 1.second).ago)
        Maintenance.any_instance.expects(:remaining_miles).once
        @device.update_mileage_tasks
      end

      should 'not call remaining miles if notified_at is less than a day old' do
        @device.maintenances.first.update_attributes(notified_at: (1.day - 1.minute).ago)
        Maintenance.any_instance.expects(:remaining_miles).never
        @device.update_mileage_tasks
      end
    end
  end

  context 'latest_status' do
    context 'support ignition' do
      setup do
        @device = FactoryGirl.build(:device, last_gps_reading: nil)
        @device.stubs(:supports_ignition?).returns(true)
      end

      context 'device without last gps reading' do
        should 'return -' do
          assert_equal '-', @device.latest_status
        end
      end

      context 'device with last_gps_reading' do
        setup do
          @device.last_gps_reading = FactoryGirl.build(:reading, ignition: nil)
        end
        context 'ignition is nil' do
          context 'speed equal to zero' do
            setup do
              @device.last_gps_reading.speed = 0
            end

            should 'return Stopped' do
              assert_equal Device::STATUS[:stopped], @device.latest_status
            end
          end

          context 'speed greater than zero' do
            setup do
              @device.last_gps_reading.speed = 1
            end

            should 'return Moving' do
              assert_equal Device::STATUS[:moving], @device.latest_status
            end
          end

          context 'when speed is nil' do
            setup do
              @device.last_gps_reading.speed = nil
            end

            should 'return Idle' do
              assert_equal Device::STATUS[:stopped], @device.latest_status
            end
          end
        end

        context 'ignition is equal to 1' do
          setup do
            @device.last_gps_reading.ignition = true
          end

          context 'when speed is nil' do
            setup do
              @device.last_gps_reading.speed = nil
            end

            should 'return Idle' do
              assert_equal Device::STATUS[:idle], @device.latest_status
            end
          end

          context 'when speed is equal to zero' do
            setup do
              @device.last_gps_reading.speed = 0
            end

            should 'return Idle' do
              assert_equal Device::STATUS[:idle], @device.latest_status
            end
          end

          context 'when speed is greater than zero' do
            setup do
              @device.last_gps_reading.speed = 1
            end

            should 'return Moving' do
              assert_equal Device::STATUS[:moving], @device.latest_status
            end
          end
        end

        context 'ignition is equal to 0' do
          setup do
            @device.last_gps_reading.ignition = false
          end

          should 'return Stopped' do
            assert_equal Device::STATUS[:stopped], @device.latest_status
          end
        end
      end
    end

    context 'when device doesn\'t support ignition and supports motion' do
      setup do
        @device = FactoryGirl.build(:device, last_gps_reading: nil)
        @device.stubs(:supports_ignition?).returns(false)
        @device.stubs(:supports_motion?).returns(true)
      end

      context 'when in_motion is nil' do
        setup do
          @device.last_gps_reading = FactoryGirl.build(:reading, in_motion: nil)
        end

        should 'return Stopped' do
          assert_equal Device::STATUS[:stopped], @device.latest_status
        end
      end

      context 'when in_motion is false' do
        setup do
          @device.last_gps_reading = FactoryGirl.build(:reading, in_motion: false)
        end

        should 'return Stopped' do
          assert_equal Device::STATUS[:stopped], @device.latest_status
        end
      end

      context 'when in_motion is true' do
        setup do
          @device.last_gps_reading = FactoryGirl.build(:reading, in_motion: true)
        end

        should 'return Moving' do
          assert_equal Device::STATUS[:moving], @device.latest_status
        end
      end
    end
  end

  context 'latest_status_description' do
    context 'when status is Moving' do
      setup do
        @device = FactoryGirl.build(:device)
        @device.last_gps_reading = FactoryGirl.build(:reading, speed: 60)
        @device.stubs(:latest_status).returns(Device::STATUS[:moving])
      end

      should 'return Moving and extra information' do
        assert_equal 'Moving (E at 60mph)', @device.latest_status_description
      end
    end

    context 'when status is other' do
      setup do
        @device = FactoryGirl.build(:device)
        @device.last_gps_reading = FactoryGirl.build(:reading, speed: 60)
        @device.stubs(:latest_status).returns('Other')
      end

      should 'return Other' do
        assert_equal 'Other', @device.latest_status_description
      end
    end
  end

  context 'latest_digital_sensor_status' do
    setup do
      @digital_sensor_reading = FactoryGirl.build(:digital_sensor_reading, value: true)
      reading = FactoryGirl.build(:reading, digital_sensor_reading: @digital_sensor_reading)
      @device = FactoryGirl.build(:device, last_gps_reading: reading)
    end

    should 'return digital sensor reading description' do
      assert_equal @digital_sensor_reading.description, @device.latest_digital_sensor_status
    end
  end

  context 'validate idle threshold must be a positive integer or zero' do
    should validate_numericality_of(:idle_threshold).is_greater_than_or_equal_to(0).only_integer.allow_nil
  end

  context 'sensor' do
    setup do
      @device = FactoryGirl.create(:device)
    end
    context 'device has got the sensor with address' do
      setup do
        @digital_sensor = FactoryGirl.create(:digital_sensor, device: @device, address: 1, name: 'Device Sensor')
      end

      should 'return device digital sensor' do
        assert_equal @digital_sensor.id, @device.sensor(1).id
      end
    end

    context 'device hasn\'t got the sensor with address' do
      context 'device hasn\'t got an account' do
        setup do
          @device.update_attribute(:account_id, nil)
        end

        should 'return a default digital sensor' do
          assert_equal 'Digital Sensor 1', @device.sensor(1).name
        end
      end

      context 'device has got an account' do
        context 'account has got a sensor template for address' do
          setup do
            @template_sensor = FactoryGirl.create(:sensor_template, account: @device.account)
            @digital_sensor = @device.sensor(1)
          end

          should 'return a digital sensor with account template data' do
            assert_equal DigitalSensor, @digital_sensor.class
            assert_equal 'Sensor Template', @digital_sensor.name
          end
        end

        context 'account hasn\'t got a sensor template for address' do
          setup do
            @digital_sensor = @device.sensor(1)
          end
          should 'return a default digital sensor' do
            assert_equal 'Digital Sensor 1', @digital_sensor.name
            assert_equal 'High', @digital_sensor.high_label
            assert_equal 'Low', @digital_sensor.low_label
            assert_equal DigitalSensor::NOTIFICATION_TYPES[:disabled], @digital_sensor.notification_type
          end
        end
      end
    end
  end

  context 'update_default_digital_sensors' do
    setup do
      @device = FactoryGirl.create(:device)
    end

    context 'when digital sensors are modified' do
      context 'device without sensors' do
        setup do
          sensors = [
            { name: 'Sensor1', high_label: 'high_label', low_label: 'low_label', address: '1', notification_type: '0' },
            { name: 'Sensor2', high_label: 'high_label', low_label: 'low_label', address: '2', notification_type: '1' }
          ]
          @device.update_attributes(digital_sensors_attributes: sensors)
        end

        should 'modify account sensor templates' do
          assert_equal 2, @device.reload.account.sensor_templates.size
          assert @device.reload.account.sensor_templates.map(&:name).include?('Sensor1')
          assert @device.reload.account.sensor_templates.map(&:name).include?('Sensor2')
        end
      end

      context 'device with sensors' do
        setup do
          sensors = [
            { name: 'Sensor1', high_label: 'high_label', low_label: 'low_label', address: '1', notification_type: '0' },
            { name: 'Sensor2', high_label: 'high_label', low_label: 'low_label', address: '2', notification_type: '1' }
          ]
          @device.update_attributes!(digital_sensors_attributes: sensors)
          sensors2 = [
            { id: @device.digital_sensors.first.id, name: 'Sensor3', high_label: 'high_label', low_label: 'low_label', address: '1', notification_type: '0' }
          ]
          @device.update_attributes(digital_sensors_attributes: sensors2)
        end

        should 'modify account sensor templates' do
          assert_equal 2, @device.reload.account.sensor_templates.size
          assert @device.account.reload.sensor_templates.map(&:name).include?('Sensor2')
          assert @device.account.reload.sensor_templates.map(&:name).include?('Sensor3')
        end
      end
    end

    context 'when digital sensors are not modified' do
      setup do
        sensors = [
          { name: 'Sensor1', high_label: 'high_label', low_label: 'low_label', address: '1', notification_type: '0' },
          { name: 'Sensor2', high_label: 'high_label', low_label: 'low_label', address: '2', notification_type: '1' }
        ]
        @device.update_attributes(digital_sensors_attributes: sensors)
        @expected_sensor_templates = @device.reload.account.sensor_templates

        @device.update_attributes(name: 'new name')
      end

      should 'not modify account sensor templates' do
        assert_equal @expected_sensor_templates, @device.reload.account.sensor_templates
      end
    end
  end

  context 'on_subscribed_users' do
    setup do
      User.delete_all
      @device = FactoryGirl.create(:device)
      FactoryGirl.create(:user, enotify: User::NOTIFICATIONS[:disabled])
      @users_to_notify = []
      @users_to_notify << FactoryGirl.create(:user, account: @device.account, enotify: User::NOTIFICATIONS[:all_in_account], subscribed_notifications: [])
    end

    context 'when notification type is :offline' do
      setup do
        @users_to_notify << FactoryGirl.create(:user, account: @device.account, enotify: User::NOTIFICATIONS[:all_in_account], subscribed_notifications: [:offline, :geofence])
        @users_to_notify << FactoryGirl.create(:user, account: @device.account, enotify: User::NOTIFICATIONS[:all_in_account], subscribed_notifications: [:startup])
      end

      should 'notify all subscribed users with :offline notifications' do
        @device.on_subscribed_users(:offline) do |user|
          assert @users_to_notify.include?(user) if user.subscribed_notifications?(:offline)
          @users_to_notify.delete(user)
        end

        assert_equal [], @users_to_notify.select { |user| user.subscribed_notifications?(:offline) }
        assert_equal @users_to_notify, @users_to_notify.select { |user| !user.subscribed_notifications?(:offline) }
      end
    end

    context 'when notification type is :idling' do
      setup do
        @users_to_notify << FactoryGirl.create(:user, account: @device.account, enotify: User::NOTIFICATIONS[:all_in_account], subscribed_notifications: [:idling, :geofence])
        @users_to_notify << FactoryGirl.create(:user, account: @device.account, enotify: User::NOTIFICATIONS[:all_in_account], subscribed_notifications: [:startup])
      end

      should 'notify all subscribed users with :idling notifications' do
        @device.on_subscribed_users(:idling) do |user|
          assert @users_to_notify.include?(user) if user.subscribed_notifications?(:idling)
          @users_to_notify.delete(user)
        end

        assert_equal [], @users_to_notify.select { |user| user.subscribed_notifications?(:idling) }
        assert_equal @users_to_notify, @users_to_notify.select { |user| !user.subscribed_notifications?(:idling) }
      end
    end

    context 'when notification type is :sensors' do
      setup do
        @users_to_notify << FactoryGirl.create(:user, account: @device.account, enotify: User::NOTIFICATIONS[:all_in_account], subscribed_notifications: [:startup, :sensor])
        @users_to_notify << FactoryGirl.create(:user, account: @device.account, enotify: User::NOTIFICATIONS[:all_in_account], subscribed_notifications: [:offline])
      end

      should 'notify all subscribed users with :sensors notifications' do
        @device.on_subscribed_users(:sensors) do |user|
          assert @users_to_notify.include?(user) if user.subscribed_notifications?(:sensors)
          @users_to_notify.delete(user)
        end

        assert_equal [], @users_to_notify.select { |user| user.subscribed_notifications?(:sensors) }
        assert_equal @users_to_notify, @users_to_notify.select { |user| !user.subscribed_notifications?(:sensors) }
      end
    end

    context 'when notification type is :speed' do
      setup do
        @users_to_notify << FactoryGirl.create(:user, account: @device.account, enotify: User::NOTIFICATIONS[:all_in_account], subscribed_notifications: [:speed, :startup, :sensor])
        @users_to_notify << FactoryGirl.create(:user, account: @device.account, enotify: User::NOTIFICATIONS[:all_in_account], subscribed_notifications: [:offline])
      end

      should 'notify all subscribed users with :speed notifications' do
        @device.on_subscribed_users(:speed) do |user|
          assert @users_to_notify.include?(user) if user.subscribed_notifications?(:speed)
          @users_to_notify.delete(user)
        end

        assert_equal [], @users_to_notify.select { |user| user.subscribed_notifications?(:speed) }
        assert_equal @users_to_notify, @users_to_notify.select { |user| !user.subscribed_notifications?(:speed) }
      end
    end

    context 'when notification type is :geofence' do
      setup do
        @users_to_notify << FactoryGirl.create(:user, account: @device.account, enotify: User::NOTIFICATIONS[:all_in_account], subscribed_notifications: [:geofence, :startup, :sensor])
        @users_to_notify << FactoryGirl.create(:user, account: @device.account, enotify: User::NOTIFICATIONS[:all_in_account], subscribed_notifications: [:offline])
      end

      should 'notify all subscribed users with :geofence notifications' do
        @device.on_subscribed_users(:geofence) do |user|
          assert @users_to_notify.include?(user) if user.subscribed_notifications?(:geofence)
          @users_to_notify.delete(user)
        end

        assert_equal [], @users_to_notify.select { |user| user.subscribed_notifications?(:geofence) }
        assert_equal @users_to_notify, @users_to_notify.select { |user| !user.subscribed_notifications?(:geofence) }
      end
    end

    context 'when notification type is :non_working' do
      setup do
        @users_to_notify << FactoryGirl.create(:user, account: @device.account, enotify: User::NOTIFICATIONS[:all_in_account], subscribed_notifications: [:geofence, :sensor])
        @users_to_notify << FactoryGirl.create(:user, account: @device.account, enotify: User::NOTIFICATIONS[:all_in_account], subscribed_notifications: [:offline])
      end

      should 'notify all users' do
        @device.on_subscribed_users(:non_working) do |user|
          assert @users_to_notify.include?(user)
          @users_to_notify.delete(user)
        end

        assert_equal [], @users_to_notify
      end
    end

    context 'when notification type is :gpio' do
      setup do
        @users_to_notify << FactoryGirl.create(:user, account: @device.account, enotify: User::NOTIFICATIONS[:all_in_account], subscribed_notifications: [:gpio, :first_movement, :sensor])
        @users_to_notify << FactoryGirl.create(:user, account: @device.account, enotify: User::NOTIFICATIONS[:all_in_account], subscribed_notifications: [:startup])
      end

      should 'notify all subscribed users with :gpio notifications' do
        @device.on_subscribed_users(:gpio) do |user|
          assert @users_to_notify.include?(user) if user.subscribed_notifications?(:gpio)
          @users_to_notify.delete(user)
        end

        assert_equal [], @users_to_notify.select { |user| user.subscribed_notifications?(:gpio) }
        assert_equal @users_to_notify, @users_to_notify.select { |user| !user.subscribed_notifications?(:gpio) }
      end
    end

    context 'when notification type is :first_movement' do
      setup do
        @users_to_notify << FactoryGirl.create(:user, account: @device.account, enotify: User::NOTIFICATIONS[:all_in_account], subscribed_notifications: [:gpio, :sensor, :first_movement])
        @users_to_notify << FactoryGirl.create(:user, account: @device.account, enotify: User::NOTIFICATIONS[:all_in_account], subscribed_notifications: [:startup])
      end

      should 'notify all subscribed users with :first_movement notifications' do
        @device.on_subscribed_users(:first_movement) do |user|
          assert @users_to_notify.include?(user) if user.subscribed_notifications?(:first_movement)
          @users_to_notify.delete(user)
        end

        assert_equal [], @users_to_notify.select { |user| user.subscribed_notifications?(:first_movement) }
        assert_equal @users_to_notify, @users_to_notify.select { |user| !user.subscribed_notifications?(:first_movement) }
      end
    end

    context 'when notification type is :startup' do
      setup do
        @users_to_notify << FactoryGirl.create(:user, account: @device.account, enotify: User::NOTIFICATIONS[:all_in_account], subscribed_notifications: [:gpio, :startup, :first_movement])
        @users_to_notify << FactoryGirl.create(:user, account: @device.account, enotify: User::NOTIFICATIONS[:all_in_account], subscribed_notifications: [:startup])
      end

      should 'notify all subscribed users with :startup notifications' do
        @device.on_subscribed_users(:startup) do |user|
          assert @users_to_notify.include?(user) if user.subscribed_notifications?(:startup)
          @users_to_notify.delete(user)
        end

        assert_equal [], @users_to_notify.select { |user| user.subscribed_notifications?(:startup) }
        assert_equal @users_to_notify, @users_to_notify.select { |user| !user.subscribed_notifications?(:startup) }
      end
    end

    context 'when notification type is :gps_unit_power' do
      setup do
        @users_to_notify << FactoryGirl.create(:user, account: @device.account, enotify: User::NOTIFICATIONS[:all_in_account], subscribed_notifications: [:gps_unit_power, :startup, :first_movement])
        @users_to_notify << FactoryGirl.create(:user, account: @device.account, enotify: User::NOTIFICATIONS[:all_in_account], subscribed_notifications: [:startup])
      end

      should 'notify all subscribed users with :gps_unit_power notifications' do
        @device.on_subscribed_users(:gps_unit_power) do |user|
          assert @users_to_notify.include?(user) if user.subscribed_notifications?(:gps_unit_power)
          @users_to_notify.delete(user)
        end

        assert_equal [], @users_to_notify.select { |user| user.subscribed_notifications?(:gps_unit_power) }
        assert_equal @users_to_notify, @users_to_notify.select { |user| !user.subscribed_notifications?(:gps_unit_power) }
      end
    end

    context 'when notification type is :maintenance' do
      setup do
        @users_to_notify << FactoryGirl.create(:user, account: @device.account, enotify: User::NOTIFICATIONS[:all_in_account], subscribed_notifications: [:maintenance, :startup, :first_movement])
        @users_to_notify << FactoryGirl.create(:user, account: @device.account, enotify: User::NOTIFICATIONS[:all_in_account], subscribed_notifications: [:startup])
      end

      should 'notify all subscribed users with :maintenance notifications' do
        @device.on_subscribed_users(:maintenance) do |user|
          assert @users_to_notify.include?(user) if user.subscribed_notifications?(:maintenance)
          @users_to_notify.delete(user)
        end

        assert_equal [], @users_to_notify.select { |user| user.subscribed_notifications?(:maintenance) }
        assert_equal @users_to_notify, @users_to_notify.select { |user| !user.subscribed_notifications?(:maintenance) }
      end
    end
  end

  context 'sync_and_create' do
    setup do
      @thing_token = 'thing-token'
      @account = FactoryGirl.create(:monkey_account)

      @params = FactoryGirl.attributes_for(:device)
      @params[:thing_token] = nil
      @params[:account_id] = @account.id

      @device = Device.new(@params)
    end

    context 'when successfully patch to QIOT' do
      setup do
        expected_body = {
          label: @params[:name],
          identities: [{ type: 'IMEI', value: @params[:imei] }],
          deleted: false,
          collection_token: @account.collection_token
        }.to_json

        QiotApi.expects(:create_thing).with(expected_body)
          .returns(success: true, data: { thing: { thing_token: @thing_token } })
      end

      should 'return no errors' do
        errors = @device.sync_and_create
        assert errors.empty?
      end

      should 'create the device' do
        @device.sync_and_create
        assert Device.find(@device.id)
      end

      should 'assign thing_token to the device' do
        @device.sync_and_create
        assert_equal Device.find(@device.id).thing_token, @thing_token
      end
    end

    context 'when post to QIOT fails' do
      setup do
        @error = 'QIOT post error'
        QiotApi.stubs(:create_thing).returns(success: false, error: @error)
      end

      should 'returns an error' do
        errors = @device.sync_and_create
        assert_equal errors.first, @error
      end

      should 'not create the device' do
        assert_no_difference 'Device.count' do
          @device.sync_and_create
        end
      end
    end

    context 'when device is invalid' do
      setup do
        @params = FactoryGirl.attributes_for(:device)
        @params[:thing_token] = nil
        @params[:name] = nil

        @device = Device.new(@params)
        QiotApi.expects(:create_thing).never
      end

      should 'return an error' do
        errors = @device.sync_and_create
        assert errors.any?
      end

      should 'not create the device' do
        assert_no_difference 'Device.count' do
          @device.sync_and_create
        end
      end
    end
  end

  context 'sync_and_update' do
    setup do
      @imei = '1234567'
      @thing_token = 'thing-token'
      @account1 = FactoryGirl.create(:account, collection_token: 'token-1')
      @account2 = FactoryGirl.create(:account, collection_token: 'token-2')
      @device = FactoryGirl.create(:device, account: @account1, thing_token: @thing_token)

      @params = { account_id: '0', name: 'updated_name', imei: @imei }
    end

    context 'when successfully patch to QIOT' do
      setup do
        expected_body = {
          label: @params[:name],
          identities: [{ type: 'IMEI', value: @params[:imei] }],
          deleted: false,
          collection_token: nil
        }.to_json

        QiotApi.expects(:update_thing).with(expected_body, @thing_token).returns(success: true)
      end

      should 'return no errors' do
        errors = @device.sync_and_update(@params)
        assert errors.empty?
      end

      should 'updates name and imei' do
        errors = @device.sync_and_update(@params)
        assert_equal @params[:name], Device.find_by(imei: @imei).name
      end
    end

    context 'when post to QIOT fails' do
      setup do
        @error = 'QIOT post error'
        QiotApi.stubs(:update_thing).returns(success: false, error: @error)
      end

      should 'returns an error' do
        errors = @device.sync_and_update(@params)
        assert_equal @error, errors.first
      end
    end

    context 'when device is invalid' do
      setup do
        @params = { account_id: '0', name: nil, imei: @imei }
        QiotApi.expects(:update_thing).never
      end

      should 'return an error' do
        errors = @device.sync_and_update(@params)
        assert errors.any?
      end
    end
  end

  context '#date_of_last_reading' do
    should 'return recorded_at of most recent reading associated to the device when any exist' do
      device = FactoryGirl.create(:device)
      reading1 = FactoryGirl.create(:reading, device: device)
      reading2 = FactoryGirl.create(:reading, device: device)
      assert_equal(reading2.recorded_at, device.date_of_last_reading)
    end

    should 'return nil if no readings exist' do
      device = FactoryGirl.create(:device)
      assert_nil(device.date_of_last_reading)
    end
  end

  # TODO revisit with new job handling
  # context 'after_update :reset_idle_threshold_jobs, if: :idle_threshold_changed?' do
  #   setup do
  #     @device = FactoryGirl.create(:device)
  #     @idle_event = FactoryGirl.create(:idle_event, device: @device)
  #   end
  #
  #   context 'when idle_threshold does not change' do
  #     should 'not call callback' do
  #       @device.expects(:re_enqueue_open_idle_event).never
  #       @device.update_attributes(name: 'Device name')
  #     end
  #   end
  #
  #   context 'when idle_threshold changes' do
  #     should 'call callback' do
  #       @device.expects(:re_enqueue_open_idle_event).once
  #       @device.update_attributes(idle_threshold: 3000)
  #     end
  #   end
  # end
  #
  # context 're_enqueue_current_idle_event_job' do
  #   context 'there is an open idle_event' do
  #     setup do
  #       @device = FactoryGirl.create(:device)
  #       @idle_event = FactoryGirl.create(:idle_event, started_at: Time.now - 4.days, device: @device)
  #
  #       @device.update_attributes!(open_idle_event: @idle_event)
  #     end
  #
  #     should 're enqueue open idle_event for @device' do
  #       @idle_event.expects(:enqueue_job_for_time_exceeded).once
  #
  #       @device.re_enqueue_open_idle_event
  #     end
  #
  #     should 'expire telematics stomper cache' do
  #       TelematicsStomper.expects(:note_telematics_change).once
  #
  #       @device.re_enqueue_open_idle_event
  #     end
  #   end
  #
  #   context 'there isn\'t an open idle_event' do
  #     setup do
  #       @device = FactoryGirl.create(
  #         :device,
  #         open_idle_event: nil
  #       )
  #     end
  #
  #     should 're enqueue open idle_event for @device' do
  #       IdleEvent.any_instance.expects(:enqueue_job_for_time_exceeded).never
  #
  #       @device.re_enqueue_open_idle_event
  #     end
  #   end
  # end
end
