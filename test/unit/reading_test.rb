require 'test_helper'

class ReadingTest < ActiveSupport::TestCase
  fixtures :readings, :geofences, :locations, :devices

  should delegate_method(:phone_number).to(:device).with_prefix
  test 'address' do
    assert_equal "20 NW Chipman Rd, Lee's Summit MO", readings(:reading5).short_address
    assert_equal "20 NW Chipman Rd, Lee's Summit MO", readings(:reading1).short_address
    assert_equal "20 NW Chipman Rd, Lee's Summit MO", readings(:reading2).short_address
    assert_equal '32.9395, -96.8244', readings(:reading3).short_address
    assert_equal '32.94, -96.8217', readings(:reading4).short_address
    assert_equal '32.9514, -96.8228', readings(:reading6).short_address
  end

  test 'speed_round' do
    assert_equal 18.0, readings(:reading1).speed
    assert_equal 24.0, readings(:reading2).speed
  end

  test 'direction_string' do
    assert_equal 'SE', readings(:reading2).direction_string
  end

  test 'fence_name' do
    assert_nil readings(:reading1).get_fence_name
    assert_equal 'work', readings(:readings_224).get_fence_name

    reading = readings(:reading1)
    reading.geofence_id = 1234 #bad geofence ID
    assert_nil reading.get_fence_name()
  end

  test 'refresh_status_and_process_email_notification' do
    r = Reading.new
    r.device = Device.new
    [:non_working_hours_movement_notifications, :startup_notifications, :first_movement_notifications,
     :speed_notifications, :movement_alerts, :geofence_notifications, :gps_unit_power_notifications].each do |method|
      r.expects(method).once
    end
    r.refresh_status_and_process_email_notification
  end

  test 'apply_geofences with geofence at device level' do
    GeofenceViolation.delete_all

    reading = Reading.create!(latitude: 32.833781, longitude: -96.756807, device_id: 1, recorded_at: DateTime.now)
    reading.apply_geofences
    assert_equal 'enter', reading.geofence_event_type
    assert_equal 1, reading.geofence_id

    reading = Reading.create!(latitude: 32.833782, longitude: -96.756807, device_id: 1, recorded_at: DateTime.now)
    reading.apply_geofences
    assert_equal 'normal', reading.geofence_event_type

    reading = Reading.create!(latitude: 33.833783, longitude: -96.756807, device_id: 1, recorded_at: DateTime.now)
    reading.apply_geofences
    assert_equal 'exit', reading.geofence_event_type
    assert_equal 1, reading.geofence_id

    reading = Reading.create!(latitude: 32.833784, longitude: -96.756807, device_id: 1, recorded_at: DateTime.now)
    reading.apply_geofences
    assert_equal 'enter', reading.geofence_event_type
    assert_equal 1, reading.geofence_id

    reading = Reading.create!(latitude: 32.940955, longitude: -96.822224, device_id: 1, recorded_at: DateTime.now)
    reading.apply_geofences
    assert_equal 'exit', reading.geofence_event_type
    assert_equal 1, reading.geofence_id
  end

  test 'apply_geofences with geofence at account level' do
    GeofenceViolation.delete_all
    device = Device.find(1)

    reading = Reading.create!(latitude: 32.7977, longitude: -79.9603, device: device, recorded_at: DateTime.now)
    reading.apply_geofences
    assert_equal 'enter', reading.geofence_event_type
    assert_equal 4, reading.geofence_id

    reading = Reading.create!(latitude: 32.7977, longitude: -79.9633, device: device, recorded_at: DateTime.now) # NOTE less than MIN_JITTER_DISTANCE
    reading.apply_geofences
    assert_equal 'normal', reading.geofence_event_type
    assert_equal 4, reading.geofence_id

    reading = Reading.create!(latitude: 32.7977, longitude: -79.9633, device: device, recorded_at: DateTime.now, speed: 50.0)
    reading.apply_geofences
    assert_equal 'exit', reading.geofence_event_type
    assert_equal 4, reading.geofence_id

    reading = Reading.create!(latitude: 32.7977, longitude: -79.9603, device_id: 7, recorded_at: DateTime.now)
    reading.apply_geofences
    assert_nil reading.geofence_event_type

    reading = Reading.create!(latitude: 32.7977, longitude: -79.9603, device_id: 1, recorded_at: DateTime.now)
    reading.apply_geofences
    assert_equal 'enter', reading.geofence_event_type
    assert_equal 4, reading.geofence_id

    reading = Reading.create!(latitude: 32.7977, longitude: -79.9603, device_id: 7, recorded_at: DateTime.now)
    reading.apply_geofences
    assert_nil reading.geofence_event_type
  end

  context 'geofence_notifications' do
    setup do
      @reading = Reading.new
    end

    should 'call apply geofence' do
      @reading.expects(:apply_geofences).once
      @reading.geofence_notifications
    end

    should 'not send notification' do
      Notifier.expects(:send_notify_reading_to_users).never
      @reading.geofence_notifications
    end

    context 'with enough reading data' do
      setup do
        @reading.recorded_at = Time.now
        @reading.stubs(geofence_enter?: true)
      end

      should 'not send notifications' do
        Notifier.expects(:send_notify_reading_to_users).never
        @reading.geofence_notifications
      end

      context 'and enough device data' do
        setup do
          @reading.device = Device.new
          @reading.device.provision_status_id = ProvisionStatus::STATUS_ACTIVE
        end

        should 'not send notifications' do
          Notifier.expects(:send_notify_reading_to_users).never
          @reading.geofence_notifications
        end

        context 'and enough geofence data' do
          setup do
            @reading.geofence = Geofence.new
            @reading.geofence.stubs(notify_enter_exit?: true)
            @reading.stubs(get_fence_name: 'test', short_address: 'Bigfork, MT')
          end

          should 'send notifications' do
            Notifier.expects(:send_notify_reading_to_users).with('entered geofence test at Bigfork, MT', @reading).once
            @reading.geofence_notifications
          end
        end
      end
    end

    context 'with enough reading data' do
      setup do
        @reading.recorded_at = Time.now
        @reading.stubs(geofence_exit?: true)
      end

      should 'not send notifications' do
        Notifier.expects(:send_notify_reading_to_users).never
        @reading.geofence_notifications
      end

      context 'and enough device data' do
        setup do
          @reading.device = Device.new
          @reading.device.provision_status_id = ProvisionStatus::STATUS_ACTIVE
        end

        should 'not send notifications' do
          Notifier.expects(:send_notify_reading_to_users).never
          @reading.geofence_notifications
        end

        context 'and enough geofence data' do
          setup do
            @reading.geofence = Geofence.new
            @reading.geofence.stubs(notify_enter_exit?: true)
            @reading.stubs(get_fence_name: 'test', short_address: 'Bigfork, MT')
          end

          should 'send notifications' do
            Notifier.expects(:send_notify_reading_to_users).with('exited geofence test at Bigfork, MT', @reading, :geofence).once
            @reading.geofence_notifications
          end
        end
      end
    end
  end

  context 'movement alerts' do
    context 'empty' do
      setup do
        alerts = stub
        alerts.expects(:any?).returns(false).once
        alerts.expects(:each).never

        @reading = Reading.new
        device = Device.new
        device.stubs(movement_alerts: stub(open_alerts: alerts))
        @reading.device = device
      end

      should 'not send alerts' do
        assert_nil @reading.movement_alerts
      end
    end

    context 'with data' do
      setup do
        @reading = Reading.new
        @alert = stub(id: 1, device_id: 1)
        alerts = [@alert, @alert]

        device = Device.new
        device.stubs(movement_alerts: stub(open_alerts: alerts))
        @reading.device = device
      end

      should 'send alert' do
        @alert.expects(:is_violated_by).with(@reading).returns(false, true).twice
        @alert.expects(:mark_as_closed).with(@reading).once
        @alert.expects(:deliver_now).once
        @reading.movement_alerts
      end
    end
  end

  context 'speed notifications' do
    setup do
      @reading = setup_speed_notification_reading
    end

    context 'not enough data' do
      setup do
        Notifier.expects(:send_notify_reading_to_users).never
      end

      context 'without group or account info' do
        setup do
          @reading = setup_speed_notification_reading
          @reading.device.expects(:speeding_at).never
        end

        context 'device inactive' do
          setup do
            @reading.device.stubs(active?: false)
          end

          should 'not send notifications' do
            assert_nil @reading.speed_notifications
          end
        end
      end

      context 'with group and account info' do
        setup do
          @reading.device.stubs(speeding_at: true)
          @reading.group.max_speed = 70
          @reading.account.max_speed = 70
        end

        should 'not send notifications with speed 0' do
          @reading.device.expects(:update_attribute).with(:speeding_at, nil).once
          @reading.speed =0
          @reading.speed_notifications
        end

        should 'not send notifications with speed 30' do
          @reading.speed =30
          @reading.speed_notifications
        end
      end
    end

    context 'violating reading' do
      setup do
        @reading.recorded_at = Time.now
        @reading.speed = 130
        @reading.group.max_speed = 70
        @reading.account.max_speed = 75
        @reading.device.stubs(max_speed: 75)
      end

      should 'send one notification' do
        Notifier.expects(:send_notify_reading_to_users).with('maximum speed of 75 MPH exceeded', @reading, :speed).once
        @reading.expects(:set_event_type).with(EventTypes::Speed, true)
        @reading.device.expects(:update_attribute).with(:speeding_at, @reading.recorded_at).once
        @reading.speed_notifications
      end
    end
  end

  context 'first movement' do
    context 'not enough data' do
      setup do
        Notifier.expects(:send_notify_reading_to_users).never
        @reading = Reading.new
      end

      should 'not send notifications' do
        assert_nil @reading.first_movement_notifications
      end

      context 'with device' do
        setup do
          @reading.device = Device.new
        end
        should 'not send notifications' do
          assert_nil @reading.first_movement_notifications
        end
        context 'notify_on_first_movement true' do
          setup do
            @reading.device.stubs(notify_on_first_movement?: true)
          end

          should 'not send notifications when speed 0' do
            @reading.speed =0
            assert_nil @reading.first_movement_notifications
          end

          should 'not send notifications when speed > 0 but recorded_at < today' do
            @reading.speed =1
            @reading.recorded_at = DateTime.now - 1.day
            assert_nil @reading.first_movement_notifications
          end
        end
      end
    end

    context 'notify_on_first_movement true, speed > 0 and recorded_at > beginning of day' do
      setup do
        @reading = Reading.new
        @reading.device = Device.new
        @reading.device.stubs(notify_on_first_movement?: true)
        @reading.device.expects(:update_attribute).once
        @reading.speed =20
        @reading.recorded_at = DateTime.now + 1.day
      end

      should 'send notifications' do
        Notifier.expects(:send_notify_reading_to_users).once
        @reading.first_movement_notifications
      end
    end
  end

  context 'power up' do
    setup do
      @reading = Reading.new
    end

    context 'with no power up info' do
      should 'not send notifications' do
        Notifier.expects(:send_notify_reading_to_users).never
        @reading.startup_notifications
      end
    end

    context 'with power up info' do
      setup do
        @reading.stubs(power_up?: true)
      end

      should 'send notifications' do
        Notifier.expects(:send_notify_reading_to_users).with('was powered up', @reading, :startup).once
        @reading.startup_notifications
      end
    end
  end

  context 'non_working_hours_movement' do
    context 'not enough data' do
      setup do
        @reading = Reading.new
      end

      should 'not send notifications' do
        assert_nil @reading.non_working_hours_movement_notifications
      end

      context 'with device not subscribed' do
        setup do
          @reading.device = Device.new
        end

        should 'not send notifications' do
          assert_nil @reading.non_working_hours_movement_notifications
        end
      end
    end

    context 'enough data' do
      setup do
        @reading = Reading.new
        @reading.device = Device.new
        @reading.device.stubs(notify_on_working_hours?: true)
        @reading.account = Account.new
        @reading.speed = 20
      end

      context 'without notified hours violation' do
        setup do
          @reading.device.stubs(has_notified_working_hours_violation?: false)
          @reading.account.stubs(outside_working_hours?: true)
        end

        should 'return nil if the reading.speed is nil' do
          @reading.speed = nil
          assert_nil @reading.non_working_hours_movement_notifications
        end

        should 'send notification and set has_notified_working_hours_violation to true' do
          Notifier.expects(:send_notify_reading_to_users).with('reported movement outside of working hours', @reading, :non_working).once
          @reading.device.expects(:update_attribute).with(:has_notified_working_hours_violation, true).once
          @reading.non_working_hours_movement_notifications
        end
      end

      context 'with notified hours violation' do
        setup do
          @reading.device.stubs(has_notified_working_hours_violation?: true)
          @reading.account.stubs(outside_working_hours?: false)
        end

        should 'not send notification and set has_notified_working_hours_violation to false' do
          Notifier.expects(:send_notify_reading_to_users).never
          @reading.device.expects(:update_attribute).with(:has_notified_working_hours_violation, false).once
          @reading.non_working_hours_movement_notifications
        end
      end
    end
  end

  context 'consider_gateway_event_type' do
    setup do
      @reading = Reading.new(recorded_at: Time.now)
    end

    context 'for speeding readings' do
      setup do
        @et =  EventTypes::Speed
      end

      should "set properly event_type as speed with gateway_event_type as speed alert" do
        @reading.gateway_event_type = 'speed alert'

        @reading.consider_gateway_event_type
        assert_equal @reading.event_type, @et
      end

      should "set properly event_type as speed with gateway_event_type as speeding" do
        @reading.gateway_event_type = 'speeding'

        @reading.consider_gateway_event_type
        assert_equal @reading.event_type, @et
      end
    end

    context 'for stop readings' do
      setup do
        @et =  EventTypes::Stop
      end

      should 'set properly event_type as speed with gateway_event_type as startstop_et41' do
        @reading.gateway_event_type = 'startstop_et41'

        @reading.consider_gateway_event_type
        assert_equal @reading.event_type, @et
      end
    end

    context 'for calamp 3035 data' do
      setup do
        @reading.device = Device.new(device_type: 'lmu3035')
      end

      should 'ignition is ON when DIN4 is 1 and no event code says otherwise' do
        @reading.data['io'] = {'din4' => 1}
        assert_equal true,@reading.ignition

        @reading.data['eng'] = {'ign' => 0}
        assert_equal true,@reading.ignition

        @reading.gateway_event_type = Reading::LOCATED
        assert_equal true,@reading.ignition
      end

      should 'ignition is OFF when DIN4 is 0 and no event code says otherwise' do
        @reading.data['io'] = {'din4' => 0}
        assert_equal false,@reading.ignition

        @reading.data['eng'] = {'ign' => 1}
        assert_equal false,@reading.ignition

        @reading.gateway_event_type = Reading::LOCATED
        assert_equal false,@reading.ignition
      end

      should 'ignition is OFF when DIN4 is 1 and an event code says otherwise' do
        @reading.data['io'] = {'din4' => 1}
        assert_equal true,@reading.ignition

        @reading.gateway_event_type = Reading::IGNITION_OFF
        assert_equal false,@reading.ignition

        @reading.gateway_event_type = Reading::IGNITION_TRANSITION_OFF
        assert_equal false,@reading.ignition
      end

      should 'ignition is ON when DIN4 is 0 and an event code says otherwise' do
        @reading.data['io'] = {'din4' => 0}
        assert_equal false,@reading.ignition

        @reading.gateway_event_type = Reading::IGNITION_ON
        assert_equal true,@reading.ignition

        @reading.gateway_event_type = Reading::IGNITION_TRANSITION_ON
        assert_equal true,@reading.ignition
      end
    end

    context 'ignition readings' do
      setup do
        @reading.save!
      end

      should 'set to Ignition On if virtual' do
        @reading.update_attributes(gateway_event_type: 'Virtual Ignition On')
        @reading.consider_gateway_event_type
        assert_equal 'Ignition On', @reading.reload.gateway_event_type
      end

      should 'set to Ignition Off if virtual' do
        @reading.update_attributes(gateway_event_type: 'Virtual Ignition Off')
        @reading.consider_gateway_event_type
        assert_equal 'Ignition Off', @reading.reload.gateway_event_type
      end

      ['Ignition On Event', 'Virtual Ignition On Event'].each do |event|
        should "set to Engine On if event: #{event}" do
          @reading.update_attributes(gateway_event_type: event)
          @reading.consider_gateway_event_type
          assert_equal EventTypes::EngineOn, @reading.reload.event_type
        end
      end

      ['Ignition Off Event', 'Virtual Ignition Off Event'].each do |event|
        should "set to Engine Off if event: #{event}" do
          @reading.update_attributes(gateway_event_type: event)
          @reading.consider_gateway_event_type
          assert_equal EventTypes::EngineOff, @reading.reload.event_type
        end
      end
    end

    context 'gpio' do
      setup do
        @reading.save!
      end

      should 'set gpio1 to true if Aux input high' do
        @reading.update_attributes(gateway_event_type: 'Aux Input High')
        @reading.consider_gateway_event_type
        assert @reading.reload.gpio1
      end

      should 'set gpio1 to false if Aux input low' do
        @reading.update_attributes(gateway_event_type: 'Aux Input Low')
        @reading.consider_gateway_event_type
        assert_not @reading.reload.gpio1
      end
    end
  end

  context 'show_event_type' do
    setup do
      @reading = Reading.new(recorded_at: Time.now)
    end

    should 'return event_type_str for Speed' do
      @reading.event_type =  EventTypes::Speed
      assert_equal 'Speed', @reading.show_event_type
    end

    should 'return event_type_str for Idling' do
      @reading.event_type =  EventTypes::Idling
      assert_equal 'Idling', @reading.show_event_type
    end

    should 'return event_type_str for EngineOn' do
      @reading.event_type =  EventTypes::EngineOn
      assert_equal 'Engine On', @reading.show_event_type
    end

    should 'return event_type_str for EngineOff' do
      @reading.event_type =  EventTypes::EngineOff
      assert_equal 'Engine Off', @reading.show_event_type
    end

    should 'return event_type_str for Stop' do
      @reading.event_type =  EventTypes::Stop
      assert_equal 'Stop', @reading.show_event_type
    end

    should 'return gateway_event_type in case event_type is nil' do
      @reading.gateway_event_type = 'Gateway Event Type'
      assert_equal 'Gateway Event Type', @reading.show_event_type
    end

    should 'return gateway_event_type in case gateway_event_type is input_low_1' do
      digital_sensor = DigitalSensor.build_sensor(1, nil)
      digital_sensor_reading = DigitalSensorReading.new(digital_sensor: digital_sensor, value: false)
      @reading.digital_sensor_reading =  digital_sensor_reading
      @reading.event_type = EventTypes::AssetHighToLow
      assert_equal 'Digital Sensor 1 (Low)', @reading.show_event_type
    end

    should 'return gataway_event_type in case gateway_event_type is input_high_1' do
      digital_sensor = DigitalSensor.build_sensor(1, nil)
      digital_sensor_reading = DigitalSensorReading.new(digital_sensor: digital_sensor, value: true)
      @reading.digital_sensor_reading =  digital_sensor_reading
      @reading.event_type = EventTypes::AssetLowToHigh
      assert_equal 'Digital Sensor 1 (High)', @reading.show_event_type
    end

    should 'return event_type_str for event_normal' do
      @reading.gateway_event_type = 'event_normal'
      assert_equal 'Asset Stopped', @reading.show_event_type
    end

    should 'return event_type_str for event_motion' do
      @reading.gateway_event_type = 'event_motion'
      assert_equal 'Asset Start Motion', @reading.show_event_type
    end

    should 'return event_type_str for event_moving' do
      @reading.gateway_event_type = 'event_moving'
      assert_equal 'Asset Moving', @reading.show_event_type
    end

    should 'return event_type_str form event_stopped' do
      @reading.gateway_event_type = 'event_stopped'
      assert_equal 'Asset Stop Motion', @reading.show_event_type
    end

    should 'return event_type_str form event_backup_power_low' do
      @reading.gateway_event_type = 'event_backup_power_low'
      assert_equal 'Asset GPS Unit Battery Low', @reading.show_event_type
    end

    should 'return event_type_str form no_motion' do
      @reading.gateway_event_type = 'no_motion'
      assert_equal 'Stopped', @reading.show_event_type
    end
  end

  test 'should return Hard Bracking for readings with Deacceleration Alert on gateway_event_type' do
    r = Reading.new(recorded_at: Time.now)
    r.gateway_event_type = 'Deaccelleration Alert'
    assert_equal 'Hard Braking', r.display_event_type
  end

  context 'display speed' do
    setup do
      @reading = Reading.new(recorded_at: Time.now)
    end

    should 'display N/A for a reading with speed set as nil' do
      assert_equal 'N/A', @reading.display_speed
    end

    should 'display speed rounded' do
      @reading.speed = 14.1
      assert_equal 14, @reading.display_speed
    end
  end

  context 'generate direction string' do
    should 'return n/a called with nil param' do
      assert_equal 'n/a', Reading.generate_direction_string(nil)
    end

    should 'return n if called with direction lower than 22.5' do
      assert_equal 'n', Reading.generate_direction_string(20.0)
    end

    should 'return n if called with direction upper than 337.5' do
      assert_equal 'n', Reading.generate_direction_string(340.0)
    end

    should 'return ne if called with direction between 22.5 and 67.5' do
      assert_equal 'ne', Reading.generate_direction_string(23.30)
    end

    should 'return e if called with direction between 67.5 and 112.5' do
      assert_equal 'e', Reading.generate_direction_string(70.30)
    end

    should 'return se if called with direction between 112.5 and 157.5' do
      assert_equal 'se', Reading.generate_direction_string(123.30)
    end

    should 'return s if called with direction between 157.5 and 202.5' do
      assert_equal 's', Reading.generate_direction_string(170.30)
    end

    should 'return sw if called with direction between 202.5 and 247.5' do
      assert_equal 'sw', Reading.generate_direction_string(230.30)
    end

    should 'return w if called with direction between 247.5 and 292.5' do
      assert_equal 'w', Reading.generate_direction_string(250.30)
    end

    should 'return nw if called with direction between 292.5 and 337.5' do
      assert_equal 'nw', Reading.generate_direction_string(300.30)
    end
  end

  context 'fence_description' do
    setup do
      @reading = Reading.new(recorded_at: Time.now)
    end

    context 'with geofence associated' do
      setup do
        g = Geofence.new(name: 'Test', latitude: 1.2, longitude: 1.4, radius: 20)
        g.save
        @reading.geofence_id = g.id
      end

      should 'return entering and fence name if have a geofence associated' do
        @reading.geofence_event_type = 'enter'
        assert_equal 'entering Test', @reading.fence_description
      end

      should 'return exiting and fence name if have a geofence associated' do
        @reading.geofence_event_type = 'exit'
        assert_equal 'exiting Test', @reading.fence_description
      end
    end
  end

  context 'first_movement_notifications method' do
    context 'for device with notify_on_first_movement set as false' do
      setup do
        Device.where(imei: 2330).delete_all
        device = Device.create(name: 'Device for first movement alert testing', imei: 2330, notify_on_first_movement: false)
        @reading = Reading.new(latitude: 1.2, longitude: 1.4, recorded_at: Time.now, device_id: device.id)
      end

      should 'not send email of first movement alert for each user' do
        Notifier.expects(:send_notify_reading_to_users).never
        @reading.first_movement_notifications
      end
    end

    context 'for device with notify_on_first_movement set as true, most_recent_first_movement as nil and reading with speed as nil' do
      setup do
        Device.where(imei: 2330).delete_all
        device = Device.create(name: 'Device for first movement alert testing', imei: 2330, notify_on_first_movement: true, most_recent_first_movement: nil)
        @reading = Reading.new(latitude: 1.2, longitude: 1.4, recorded_at: Time.now, device_id: device.id)
      end

      should 'not send email of first movement alert for each user' do
        Notifier.expects(:send_notify_reading_to_users).never
        @reading.first_movement_notifications
      end
    end

    context 'for device with notify_on_first_movement set as true, most_recent_first_movement as nil and reading with speed as 0' do
      setup do
        Device.where(imei: 2330).delete_all
        device = Device.create(name: 'Device for first movement alert testing', imei: 2330, notify_on_first_movement: true, most_recent_first_movement: nil)
        @reading = Reading.new(latitude: 1.2, longitude: 1.4, speed: 0, data: { gps: {speed: 0} }, recorded_at: Time.now, device_id: device.id)
      end

      should 'not send email of first movement alert for each user' do
        Notifier.expects(:send_notify_reading_to_users).never
        @reading.first_movement_notifications
      end
    end

    context 'for device with notify_on_first_movement set as true, most_recent_first_movement as nil and reading with speed over 0' do
      setup do
        Device.where(imei: 2330).delete_all
        device = Device.create(name: 'Device for first movement alert testing', imei: 2330, notify_on_first_movement: true, most_recent_first_movement: nil, thing_token: '11143')
        @reading = Reading.new(latitude: 1.2, longitude: 1.4, speed: 60, data: { gps: { speed: MPH_60 } }, recorded_at: Time.now, device_id: device.id)
      end

      should 'send email of first movement alert for each user' do
        Notifier.expects(:send_notify_reading_to_users).once
        @reading.first_movement_notifications
      end
    end

    context 'for device with notify_on_first_movement set as true, most_recent_first_movement set a day before reading.recorded_at and speed as nil' do
      setup do
        Device.where(imei: 2330).delete_all
        Account.delete_all
        account = Account.create(company: 'Company', zip: 122, time_zone: 'Central Time (US & Canada)')
        device = Device.create(name: 'Device for first movement alert testing', imei: 2330, notify_on_first_movement: true, most_recent_first_movement: DateTime.now.in_time_zone(account.try :time_zone) - 1.day, account_id: account.id, thing_token: '11144')
        @reading = Reading.new(latitude: 1.2, longitude: 1.4, recorded_at: Time.now, device_id: device.id)
      end

      should 'not send email of first movement alert for each user' do
        Notifier.expects(:send_notify_reading_to_users).never
        @reading.first_movement_notifications
      end
    end

    context 'for device with notify_on_first_movement set as true, most_recent_first_movement set a day before reading.recorded_at and speed as 0' do
      setup do
        Device.where(imei: 2330).delete_all
        Account.delete_all
        account = Account.create(company: 'Company', zip: 122, time_zone: 'Central Time (US & Canada)')
        device = Device.create(name: 'Device for first movement alert testing', imei: 2330, notify_on_first_movement: true, most_recent_first_movement: DateTime.now.in_time_zone(account.try :time_zone) - 1.day, account_id: account.id, thing_token: '11145')
        @reading = Reading.new(latitude: 1.2, longitude: 1.4, speed: 0, data: { gps: { speed: 0 } }, recorded_at: Time.now, device_id: device.id)
      end

      should 'not send email of first movement alert for each user' do
        Notifier.expects(:send_notify_reading_to_users).never
        @reading.first_movement_notifications
      end
    end

    context 'for device with notify_on_first_movement set as true, most_recent_first_movement set a day before reading.recorded_at and speed as 60' do
      setup do
        Device.where(imei: 2330).delete_all
        Account.delete_all
        account = Account.create(company: 'Company', zip: 122, time_zone: 'Central Time (US & Canada)')
        device = Device.create(name: 'Device for first movement alert testing', imei: 2330, notify_on_first_movement: true, most_recent_first_movement: DateTime.now.in_time_zone(account.try :time_zone) - 1.day, account_id: account.id, thing_token: '11146')
        @reading = device.readings.new(latitude: 1.2, longitude: 1.4, speed: 60, data: { gps: { speed: MPH_60 } }, recorded_at: Time.now)
      end

      should 'not send email of first movement alert for each user' do
        Notifier.expects(:send_notify_reading_to_users).once
        @reading.first_movement_notifications
      end
    end

    context 'for device with notify_on_first_movement set as true, most_recent_first_movement set same day as reading.recorded_at and speed as nil' do
      setup do
        Device.where(imei: 2330).delete_all
        Account.delete_all
        account = Account.create(company: 'Company', zip: 122, time_zone: 'Central Time (US & Canada)')
        device = Device.create(name: 'Device for first movement alert testing', imei: 2330, notify_on_first_movement: true, most_recent_first_movement: DateTime.now.in_time_zone(account.try :time_zone), account_id: account.id, thing_token: '11147')
        @reading = Reading.new(latitude: 1.2, longitude: 1.4, recorded_at: Time.now, device_id: device.id)
      end

      should 'not send email of first movement alert for each user' do
        Notifier.expects(:send_notify_reading_to_users).never
        @reading.first_movement_notifications
      end
    end

    context 'for device with notify_on_first_movement set as true, most_recent_first_movement set same day as reading.recorded_at and speed as 0' do
      setup do
        Device.where(imei: 2330).delete_all
        Account.delete_all
        account = Account.create(company: 'Company', zip: 122, time_zone: 'Central Time (US & Canada)')
        device = Device.create(name: 'Device for first movement alert testing', imei: 2330, notify_on_first_movement: true, most_recent_first_movement: DateTime.now.in_time_zone(account.try :time_zone), account_id: account.id, thing_token: '11148')
        @reading = Reading.new(latitude: 1.2, longitude: 1.4, speed: 0, data: { gps: { speed: 0 } }, recorded_at: Time.now, device_id: device.id)
      end

      should 'not send email of first movement alert for each user' do
        Notifier.expects(:send_notify_reading_to_users).never
        @reading.first_movement_notifications
      end
    end

    context 'for device with notify_on_first_movement set as true, most_recent_first_movement set same day as reading.recorded_at and speed as 60' do
      setup do
        Device.where(imei: 2330).delete_all
        Account.delete_all
        account = Account.create(company: 'Company', zip: 122, time_zone: 'Central Time (US & Canada)')
        device = Device.create(name: 'Device for first movement alert testing', imei: 2330, notify_on_first_movement: true, most_recent_first_movement: DateTime.now.in_time_zone(account.try :time_zone), account_id: account.id, thing_token: '11149')
        @reading = Reading.new(latitude: 1.2, longitude: 1.4, speed: 60, data: { gps: { speed: MPH_60 } }, recorded_at: Time.now, device_id: device.id)
      end

      should 'not send email of first movement alert for each user' do
        Notifier.expects(:send_notify_reading_to_users).never
        @reading.first_movement_notifications
      end
    end

    context 'for reading without device' do
      setup do
        @reading = Reading.new(latitude: 1.2, longitude: 1.4, recorded_at: Time.now)
      end

      should 'not send email of first movement alert for each user' do
        Notifier.expects(:send_notify_reading_to_users).never
        @reading.first_movement_notifications
      end
    end
  end

  context 'force_location method' do
    context 'for reading with location' do
      setup do
        location = Location.create(street: 'NW Chipman Rd', city: 'Lees Summit', state_name: 'MO', full_address: 'Lees Summit Jackson 20 MO NW Chipman R', county: 'Jackson', street_number: '20', state_abbr: 'MO')
        @reading = Reading.new(latitude: 1.2, longitude: 1.4, recorded_at: Time.now, location_id: location.id)
      end

      should 'return location address for linked location' do
        assert_equal '20 NW Chipman Rd, Lees Summit MO', @reading.force_location
      end
    end

    # TODO revisit w/ new geocoding
    # context 'for reading without location' do
    #   setup do
    #     Device.where(imei: 2330).delete_all
    #     device = Device.create(name: 'Device for first movement alert testing', imei: 2330)
    #     @reading = Reading.create(latitude: 42.501, longitude: -71.227, recorded_at: Time.now, device_id: device.id)
    #   end
    #
    #   should 'return location address for rgeo location' do
    #     assert_equal '9 Daniel Dr, Burlington MA', @reading.force_location
    #   end
    # end
  end

  context 'create_binary_sensor_reading' do
    setup do
      @device = FactoryGirl.create(:device)
      @device.stubs(:max_digital_sensors).returns(2)
      @reading = FactoryGirl.create(:reading, device: @device)
    end

    context 'device without sensors' do
      should 'create sensors' do
        assert_difference 'DigitalSensor.count' do
          @reading.create_binary_sensor_reading(2, true)
        end
      end

      should 'create a digital sensor reading with correct data' do
        @reading.create_binary_sensor_reading(2, true)

        digital_sensor_reading = @reading.reload.digital_sensor_reading
        assert_equal 2, digital_sensor_reading.digital_sensor.address
        assert_equal @device.id, digital_sensor_reading.digital_sensor.device.id
        assert_equal @reading.id, digital_sensor_reading.reading.id
        assert_equal true, digital_sensor_reading.value
      end
    end

    context 'device with sensors' do
      setup do
        @device.digital_sensors << @device.sensor(2)
        @device.save!
      end

      should 'not create sensor' do
        assert_no_difference 'DigitalSensor.count' do
          @reading.create_binary_sensor_reading(2, true)
        end
      end

      should 'create a digital sensor reading with correct data' do
        @reading.create_binary_sensor_reading(2, true)

        digital_sensor_reading = @reading.reload.digital_sensor_reading
        assert_equal @device.id, digital_sensor_reading.digital_sensor.device.id
        assert_equal @reading.id, digital_sensor_reading.reading.id
        assert_equal true, digital_sensor_reading.value
      end
    end

    context 'event_type' do
      context 'high_to_low' do
        setup do
          @reading.create_binary_sensor_reading(2, false)
        end
        should 'set event_type as AssetHighToLow' do
          assert_equal EventTypes::AssetHighToLow, @reading.reload.event_type
        end
      end

      context 'low_to_high' do
        setup do
          @reading.create_binary_sensor_reading(2, true)
        end

        should 'set event_type as AssetLowToHigh' do
          assert_equal EventTypes::AssetLowToHigh, @reading.reload.event_type
        end
      end
    end

    context 'digital sensor notifications' do
      setup do
        @mail = mock()
        @mail.stubs(:deliver_now).returns(nil)
        @digital_sensor = FactoryGirl.create(:digital_sensor, address: 1)
        @device = FactoryGirl.create(:device, digital_sensors: [@digital_sensor])
        @reading = FactoryGirl.create(:reading, device: @device)
        @user = FactoryGirl.create(:user, account: @device.account, enotify: User::NOTIFICATIONS[:all_in_account], subscribed_notifications: [:sensor])
        @digital_sensor_reading = FactoryGirl.create(:digital_sensor_reading)
      end

      context 'when notifications aren\'t enabled' do
        setup do
          @digital_sensor.update_attribute(:notification_type, DigitalSensor::NOTIFICATION_TYPES[:disabled])
        end

        context 'low to high transition' do
          should 'not notify user' do
            DigitalSensorMailer.expects(:digital_sensor_mail).returns(@mail).never
            @reading.create_binary_sensor_reading(1, true)
          end
        end

        context 'high to low transition' do
          should 'not notify user' do
            DigitalSensorMailer.expects(:digital_sensor_mail).returns(@mail).never
            @reading.create_binary_sensor_reading(1, false)
          end
        end
      end

      context 'when high to low notifications are enabled' do
        setup do
          @digital_sensor.update_attribute(:notification_type, DigitalSensor::NOTIFICATION_TYPES[:high_to_low])
        end

        context 'low to high transition' do
          should 'not notify user' do
            DigitalSensorMailer.expects(:digital_sensor_mail).returns(@mail).never
            @reading.create_binary_sensor_reading(1, true)
          end
        end

        context 'high to low transition' do
          should 'notify user' do
            DigitalSensorMailer.expects(:digital_sensor_mail).returns(@mail).once
            @reading.create_binary_sensor_reading(1, false)
          end

          context 'when user is not subscribed to sensors notifications' do
            setup do
              @user.update_attribute(:subscribed_notifications, [])
            end

            should 'not notify user' do
              DigitalSensorMailer.expects(:digital_sensor_mail).returns(@mail).never
              @reading.create_binary_sensor_reading(1, false)
            end
          end
        end
      end

      context 'when low to high notifications are enabled' do
        setup do
          @digital_sensor.update_attribute(:notification_type, DigitalSensor::NOTIFICATION_TYPES[:low_to_high])
        end

        context 'low to high transition' do
          should 'notify user' do
            DigitalSensorMailer.expects(:digital_sensor_mail).returns(@mail).once
            @reading.create_binary_sensor_reading(1, true)
          end
        end

        context 'high to low transition' do
          should 'not notify user' do
            DigitalSensorMailer.expects(:digital_sensor_mail).returns(@mail).never
            @reading.create_binary_sensor_reading(1, false)
          end
        end
      end

      context 'when high to low and low to high notifications are enabled' do
        setup do
          @digital_sensor.update_attribute(:notification_type, DigitalSensor::NOTIFICATION_TYPES[:both])
        end

        context 'low to high transition' do
          should 'notify user' do
            DigitalSensorMailer.expects(:digital_sensor_mail).returns(@mail).once
            @reading.create_binary_sensor_reading(1, true)
          end

          context 'when user is not subscribed to sensors notifications' do
            setup do
              @user.update_attribute(:subscribed_notifications, [])
            end

            should 'not notify user' do
              DigitalSensorMailer.expects(:digital_sensor_mail).returns(@mail).never
              @reading.create_binary_sensor_reading(1, true)
            end
          end
        end

        context 'high to low transition' do
          should 'notify user' do
            DigitalSensorMailer.expects(:digital_sensor_mail).returns(@mail).once
            @reading.create_binary_sensor_reading(1, false)
          end

          context 'when user is not subscribed to sensors notifications' do
            setup do
              @user.update_attribute(:subscribed_notifications, [])
            end

            should 'not notify user' do
              DigitalSensorMailer.expects(:digital_sensor_mail).returns(@mail).never
              @reading.create_binary_sensor_reading(1, false)
            end
          end
        end
      end

      context 'when previous digital reading has true input value' do
        setup do
          @digital_sensor.update_attribute(:notification_type, DigitalSensor::NOTIFICATION_TYPES[:both])
          last_digital_sensor_reading = FactoryGirl.create(:digital_sensor_reading, value: true)
          @digital_sensor.update_attribute(:last_digital_sensor_reading, last_digital_sensor_reading)
        end

        context 'when new reading with true input value comes' do
          should 'not notify' do
            DigitalSensorMailer.expects(:digital_sensor_mail).returns(@mail).never
            @reading.create_binary_sensor_reading(1, true)
          end
        end

        context 'when new reading with false input value comes' do
          should 'notify' do
            DigitalSensorMailer.expects(:digital_sensor_mail).returns(@mail).once
            @reading.create_binary_sensor_reading(1, false)
          end

          context 'when user is not subscribed to sensors notifications' do
            setup do
              @user.update_attribute(:subscribed_notifications, [])
            end

            should 'not notify user' do
              DigitalSensorMailer.expects(:digital_sensor_mail).returns(@mail).never
              @reading.create_binary_sensor_reading(1, false)
            end
          end
        end
      end

      context 'when previous digital reading has false input value' do
        setup do
          @digital_sensor.update_attribute(:notification_type, DigitalSensor::NOTIFICATION_TYPES[:both])
          last_digital_sensor_reading = FactoryGirl.create(:digital_sensor_reading, value: false)
          @digital_sensor.update_attribute(:last_digital_sensor_reading, last_digital_sensor_reading)
        end

        context 'when new reading with true input value comes' do
          should 'notify' do
            DigitalSensorMailer.expects(:digital_sensor_mail).returns(@mail).once
            @reading.create_binary_sensor_reading(1, true)
          end

          context 'when user is not subscribed to sensors notifications' do
            setup do
              @user.update_attribute(:subscribed_notifications, [])
            end

            should 'not notify user' do
              DigitalSensorMailer.expects(:digital_sensor_mail).returns(@mail).never
              @reading.create_binary_sensor_reading(1, true)
            end
          end
        end

        context 'when new reading with false input value comes' do
          should 'not notify' do
            DigitalSensorMailer.expects(:digital_sensor_mail).returns(@mail).never
            @reading.create_binary_sensor_reading(1, false)
          end
        end
      end
    end
  end

  context 'speed_notifications' do
    setup do
      @device = FactoryGirl.build(:device)
      @reading = FactoryGirl.build(:reading, device: @device)
    end

    should 'not raise an exception' do
      assert_nothing_raised do
        @reading.speed_notifications
      end
    end
  end

  context 'by_ids_with_location' do
    setup do
      @reading_one = FactoryGirl.create(:reading_location)

      @reading_two = FactoryGirl.create(:reading_location)

      @reading_without_location = FactoryGirl.create(:reading)

      @reading_not_in_scope = FactoryGirl.create(:reading_location)
    end

    should 'return the readings with the given ids that have a location' do
      result = Reading.by_ids_with_location([@reading_one.id, @reading_two.id, @reading_without_location.id])
      readings_with_a_location = [@reading_one, @reading_two]

      assert_equal readings_with_a_location, result
    end
  end

  private

  def setup_speed_notification_reading
    r = Reading.new
    r.group = Group.new max_speed: 0
    r.account = Account.new max_speed: 0
    r.device = Device.new
    r.device.stubs(active?: true, profile_speeds?: true)
    r
  end
end
