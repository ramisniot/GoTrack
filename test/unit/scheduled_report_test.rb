require 'test_helper'

class ScheduledReportTest < ActiveSupport::TestCase
  setup do
    # TODO Remove this once we get rid of all the fixtures
    User.delete_all
    Account.delete_all
    ScheduledReport.delete_all
    Device.delete_all
  end

  context '#not_completed' do
    setup do
      @uncompleted_scheduled_report_one = FactoryGirl.create(:scheduled_report_uncompleted)
      @uncompleted_scheduled_report_two = FactoryGirl.create(:scheduled_report_uncompleted)
      @completed_scheduled_report = FactoryGirl.create(:scheduled_report_completed)
    end

    should 'return the uncompleted scheduled reports' do
      assert_same_elements([@uncompleted_scheduled_report_one, @uncompleted_scheduled_report_two], ScheduledReport.not_completed)
    end
  end

  context '#is_outdated?' do
    setup do
      @scheduled_report = FactoryGirl.build(:scheduled_report)
      @account = FactoryGirl.create(:account)
    end

    context 'when account_id isn\'t sent as a param' do
      setup do
        @scheduled_report.stubs(:report_params).returns({ account_id: nil })
      end

      should 'return true' do
        assert @scheduled_report.is_outdated?
      end
    end

    context 'when device_id isn\'t sent as a param' do
      setup do
        @scheduled_report.stubs(:report_params).returns({ account_id: @account.id, device_id: nil })
      end

      should 'return false' do
        refute @scheduled_report.is_outdated?
      end
    end

    context 'when device_id is sent as a param' do
      should 'return true if device is inactive' do
        device = FactoryGirl.create(:inactive_device)

        @scheduled_report.stubs(:report_params).returns({ account_id: @account.id, device_id: device.id })

        assert @scheduled_report.is_outdated?
      end

      should 'return true if given device is not assigned to the given account' do
        device = FactoryGirl.create(:active_device)

        @scheduled_report.stubs(:report_params).returns({ account_id: @account.id, device_id: device.id })

        assert @scheduled_report.is_outdated?
      end
    end
  end

  context '#adjust_parameters' do
    context 'when valid_monthly_state_mileage_report_span_value? is true' do
      setup do
        @scheduled_report = FactoryGirl.build(:scheduled_report, report_span_value: 3, report_type: 'state_mileage', report_span_units: 'Months')

        @scheduled_report.adjust_parameters
      end

      should 'not change report_span_value' do
        assert_equal(3, @scheduled_report.report_span_value)
      end
    end

    context 'when valid_monthly_state_mileage_report_span_value? is false' do
      setup do
        @scheduled_report = FactoryGirl.build(:scheduled_report, report_span_value: 2)

        @scheduled_report.adjust_parameters
      end

      should 'change report_span_value to 1' do
        assert_equal(1, @scheduled_report.report_span_value)
      end
    end

    context 'when REPORT_SPANS includes report span units' do
      setup do
        @scheduled_report = FactoryGirl.build(:scheduled_report, report_span_units: 'Months')

        @scheduled_report.adjust_parameters
      end

      should 'not change report_span_units' do
        assert_equal('Months', @scheduled_report.report_span_units)
      end
    end

    context 'when REPORT_SPANS does not includes report span units' do
      setup do
        @scheduled_report = FactoryGirl.build(:scheduled_report, report_span_units: 'not included value')

        @scheduled_report.adjust_parameters
      end

      should 'change report_span_units to Days' do
        assert_equal('Days', @scheduled_report.report_span_units)
      end
    end
  end

  context '#filename' do
    should 'remove non word characters' do
      scheduled_report = FactoryGirl.build(:scheduled_report, report_name: 'report_name%')

      assert_equal('report_name.csv', scheduled_report.filename)
    end

    should 'replace white spaces with lower bar characters' do
      scheduled_report = FactoryGirl.build(:scheduled_report, report_name: 'report name')

      assert_equal('report_name.csv', scheduled_report.filename)
    end
  end

  context '#process' do
    context 'when report scheduled_for has passed' do
      context 'when report is outdated' do
        setup do
          @scheduled_report = FactoryGirl.create(:scheduled_report, scheduled_for: Time.now - 1.day)
          @scheduled_report.stubs(:is_outdated?).returns(true)
        end

        should 'destroy current report' do
          assert_difference 'ScheduledReport.count', -1 do
            @scheduled_report.process
          end
        end
      end

      context 'when report is not outdated' do
        setup do
          @scheduled_report = FactoryGirl.create(:scheduled_report, scheduled_for: Time.now - 1.day)
          @scheduled_report.stubs(:is_outdated?).returns(false)
        end

        context 'when process is success' do
          should 'complete the report' do
            @scheduled_report.expects(:complete).once

            @scheduled_report.process
          end

          should 'compute the report' do
            @scheduled_report.expects(:compute).once

            @scheduled_report.process
          end
        end

        context 'when process raises an error' do
          setup do
            @scheduled_report.stubs(:compute).raises(Exception, 'Error')
          end

          should 'call incomplete on report' do
            @scheduled_report.expects(:incomplete).once

            @scheduled_report.process
          end
        end
      end
    end

    context 'when report scheduled_for hasn\'t passed' do
      should 'enqueue scheduled report if report is uncompleted' do
        scheduled_report = FactoryGirl.create(:scheduled_report_uncompleted, scheduled_for: Time.now + 1.day)

        scheduled_report.expects(:enqueue_scheduled_report).once

        scheduled_report.process
      end

      should 'not enqueue scheduled report if report is completed' do
        scheduled_report = FactoryGirl.create(:scheduled_report_completed, scheduled_for: Time.now + 1.day)

        scheduled_report.expects(:enqueue_scheduled_report).never

        scheduled_report.process
      end
    end

    context '#compute' do
      context 'when scheduled report has data' do
        setup do
          @scheduled_report = FactoryGirl.create(:scheduled_report)
          @scheduled_report.stubs(:report_data).returns({})
        end

        should 'return true' do
          assert @scheduled_report.compute
        end
      end

      context 'when scheduled report doesn\'t have data' do
        setup do
          @scheduled_report = FactoryGirl.create(:scheduled_report, report_type: "stops")
        end

        should 'recompute the scheduled report' do
          @scheduled_report.expects(:recompute).once

          @scheduled_report.compute
        end
      end
    end

    context '#recompute' do
      context 'when report type is group_trip' do
        setup do
          @scheduled_report = FactoryGirl.create(:scheduled_report, report_type: "group_trip")

          @scheduled_report.stubs(:group_trip).returns({})
        end

        should 'call group_trip on scheduled_report' do
          @scheduled_report.expects(:group_trip).once

          @scheduled_report.recompute
        end

        should 'update report_data' do
          @scheduled_report.recompute

          assert_equal("{}", @scheduled_report.report_data)
        end
      end
    end

    context '#incomplete' do
      setup do
        @scheduled_report = FactoryGirl.create(:scheduled_report_completed, report_data: {})
      end

      should 'mark scheduled report as incompleted' do
        @scheduled_report.incomplete

        refute @scheduled_report.completed
      end

      should 'update report data as nil' do
        @scheduled_report.incomplete

        assert_nil @scheduled_report.report_data
      end
    end

    context '#complete' do
      context 'when scheduled report is completed' do
        setup do
          @scheduled_report = FactoryGirl.create(:scheduled_report_completed)
        end

        should 'return true' do
          assert @scheduled_report.complete
        end
      end

      context 'when scheduled report is incompleted' do
        setup do
          @scheduled_report = FactoryGirl.create(:scheduled_report_uncompleted)
        end

        should 'complete the scheduled report' do
          @scheduled_report.complete

          assert @scheduled_report.completed
        end

        should 'create a new scheduled report based on the old one' do
          assert_difference 'ScheduledReport.count', 1 do
            @scheduled_report.complete
          end
        end
      end
    end

    context '#deliver_now' do
      context 'when report was delivered' do
        setup do
          @scheduled_report = FactoryGirl.create(:scheduled_report)
        end

        should 'return false' do
          refute @scheduled_report.deliver_now
        end
      end

      context 'when report is incompleted' do
        setup do
          @scheduled_report = FactoryGirl.create(:scheduled_report_uncompleted, delivered_on: nil)
        end

        should 'return false' do
          refute @scheduled_report.deliver_now
        end
      end

      context 'when report is completed and wasn\'t delivered' do
        setup do
          @scheduled_report = FactoryGirl.create(:scheduled_report_completed, delivered_on: nil)
        end

        should 'return true' do
          assert @scheduled_report.deliver_now
        end

        should 'mark report as delivered' do
          @scheduled_report.deliver_now

          assert_not_nil @scheduled_report.delivered_on
        end

        should 'deliver_now the schedule report' do
          assert_difference 'ActionMailer::Base.deliveries.count', 1 do
            @scheduled_report.deliver_now
          end
        end
      end
    end

    context '#devices' do
      context 'when report params is blank' do
        setup do
          @scheduled_report = FactoryGirl.build(:scheduled_report, report_params: "")
        end

        should 'return an empty array' do
          assert_equal([], @scheduled_report.devices)
        end
      end

      context 'when report params is has an account that doesn\'t exists' do
        setup do
          @scheduled_report = FactoryGirl.build(:scheduled_report, report_params: { account_id: 0 })
        end

        should 'return an empty array' do
          assert_equal([], @scheduled_report.devices)
        end
      end

      context 'when report group_id and device_id are blanks' do
        setup do
          account = FactoryGirl.create(:account)

          @device_one = FactoryGirl.create(:active_device, account: account)
          @device_two = FactoryGirl.create(:active_device, account: account)

          @scheduled_report = FactoryGirl.build(:scheduled_report, report_params: { 'group_id' => "", 'device_id' => "", 'account_id' => account.id })
        end

        should 'return account provisioned devices' do
          assert_same_elements([@device_one, @device_two], @scheduled_report.devices)
        end
      end

      context 'when device_id is blank' do
        setup do
          @account = FactoryGirl.create(:account)
        end

        should 'return an empty array if no group is found' do
          scheduled_report = FactoryGirl.build(:scheduled_report, report_params: { 'group_id' => 0, 'device_id' => "", 'account_id' => @account.id })

          assert_equal([], scheduled_report.devices)
        end

        should 'return the devices of the given group if group exists' do
          group = FactoryGirl.create(:group, account: @account)

          device_one = FactoryGirl.create(:active_device, account: @account, group: group)
          device_two = FactoryGirl.create(:active_device, account: @account, group: group)

          scheduled_report = FactoryGirl.build(:scheduled_report, report_params: { 'group_id' => group.id, 'device_id' => "", 'account_id' => @account.id })

          assert_same_elements([device_one, device_two], scheduled_report.devices)
        end
      end

      context 'when device_id is from an existent device' do
        setup do
          account = FactoryGirl.create(:account)
          @device = FactoryGirl.create(:active_device)

          @scheduled_report = FactoryGirl.build(:scheduled_report, report_params: { 'group_id' => 0, 'device_id' => @device.id, 'account_id' => account.id })
        end

        should 'return the given device' do
          assert_equal([@device], @scheduled_report.devices)
        end
      end
    end

    context '#state_mileage' do
      setup do
        mock_now = Time.parse('2017-10-10 17:00:00 UTC')
        Time.stubs(:now).returns(mock_now)

        account = FactoryGirl.create(:account, company: 'Company Test')

        user = FactoryGirl.create(:user, account: account)

        device = FactoryGirl.create(:active_device, account: account, name: 'Device Test')

        @scheduled_report = FactoryGirl.create(
          :scheduled_report,
          user: user,
          report_name: 'Report Test',
          scheduled_for: Time.new(2017, 11, 11),
          report_params: { 'group_id' => '', 'device_id' => '', 'account_id' => account.id }
        )

        trip_event = FactoryGirl.create(
          :trip_event,
          started_at: "2017-11-09 07:22",
          device: device
        )

        reading_one = FactoryGirl.create(
          :reading_with_geofence_and_location,
          device: device,
          recorded_at: "2017-11-09 07:22"
        )

        reading_two = FactoryGirl.create(
          :reading_with_geofence_and_location,
          device: device,
          recorded_at: "2017-11-09 07:34"
        )

        reading_three = FactoryGirl.create(
          :reading_with_geofence_and_location,
          device: device,
          recorded_at: "2017-11-09 07:55"
        )

        FactoryGirl.create(
          :trip_leg,
          device: device,
          trip_event: trip_event,
          reading_start: reading_one,
          reading_stop: reading_two,
          duration: 300,
          distance: 100,
          started_at: reading_one.recorded_at,
          stopped_at: reading_two.recorded_at,
        )

        FactoryGirl.create(
          :trip_leg,
          device: device,
          trip_event: trip_event,
          reading_start: reading_two,
          reading_stop: reading_three,
          duration: 335,
          distance: 150,
          idle: 45,
          started_at: reading_two.recorded_at,
          stopped_at: reading_three.recorded_at,
        )
      end

      should 'generate the state mileage report' do
        assert_equal(read_fixture('state_mileage_report.txt').join, @scheduled_report.state_mileage)
      end
    end

    context '#group_trip' do
      setup do
        account = FactoryGirl.create(:account)

        device = FactoryGirl.create(:active_device, account: account, name: 'Device Test')

        @scheduled_report = FactoryGirl.create(
          :scheduled_report,
          scheduled_for: Time.new(2017, 11, 11),
          report_params: { 'group_id' => '', 'device_id' => '', 'account_id' => account.id }
        )

        location = FactoryGirl.create(:location)
        geofence = FactoryGirl.create(:geofence, name: 'Geofence')

        trip_event = FactoryGirl.create(
          :trip_event,
          started_at: "2017-11-09 07:22",
          device: device
        )

        reading_one = FactoryGirl.create(
          :reading,
          device: device,
          recorded_at: "2017-11-09 07:22",
          location: location,
          geofence: geofence
        )

        reading_two = FactoryGirl.create(
          :reading,
          device: device,
          recorded_at: "2017-11-09 07:34",
          location: location,
          geofence: geofence
        )

        reading_three = FactoryGirl.create(
          :reading,
          device: device,
          recorded_at: "2017-11-09 07:55",
          location: location,
          geofence: geofence
        )

        FactoryGirl.create(
          :trip_leg,
          device: device,
          trip_event: trip_event,
          reading_start: reading_one,
          reading_stop: reading_two,
          duration: 300,
          distance: 100,
          started_at: reading_one.recorded_at,
          stopped_at: reading_two.recorded_at,
        )

        FactoryGirl.create(
            :trip_leg,
            device: device,
            trip_event: trip_event,
            reading_start: reading_two,
            reading_stop: reading_three,
            duration: 335,
            distance: 150,
            idle: 45,
            started_at: reading_two.recorded_at,
            stopped_at: reading_three.recorded_at,
            )
      end

      should 'generate the group trip report' do
        assert_equal(read_fixture('group_trip_report.txt').join, @scheduled_report.group_trip)
      end
    end

    context '#stops' do
      setup do
        account = FactoryGirl.create(:account)

        device = FactoryGirl.create(:active_device, account: account, name: 'Device Test')

        @scheduled_report = FactoryGirl.create(
          :scheduled_report,
          scheduled_for: Time.new(2017, 11, 11),
          report_params: { 'group_id' => '', 'device_id' => '', 'account_id' => account.id }
        )

        location = FactoryGirl.create(:location)
        geofence = FactoryGirl.create(:geofence, name: 'Geofence')

        reading_one = FactoryGirl.create(
          :reading,
          device: device,
          recorded_at: "2017-11-10 10:22:00",
          location: location,
          geofence: geofence
        )

        reading_two = FactoryGirl.create(
          :reading,
          device: device,
          recorded_at: "2017-11-10 10:52:00",
          location: location,
          geofence: geofence
        )

        FactoryGirl.create(
          :stop_event,
          device: device,
          start_reading: reading_one,
          duration: 200,
          started_at: "2017-11-9 10:22:00"
        )

        FactoryGirl.create(
          :stop_event,
          device: device,
          start_reading: reading_two,
          duration: 250,
          started_at: "2017-11-9 10:52:00"
        )
      end

      should 'generate the stops report' do
        assert_equal(read_fixture('stops_report.txt').join, @scheduled_report.stops)
      end
    end

    context '#sensors' do
      setup do
        account = FactoryGirl.create(:account)

        device = FactoryGirl.create(:active_device, account: account, name: 'Device Test')

        @scheduled_report = FactoryGirl.create(
          :scheduled_report,
          scheduled_for: Time.new(2017, 11, 11),
          report_params: { 'group_id' => '', 'device_id' => '', 'account_id' => account.id }
        )

        location = FactoryGirl.create(:location)
        geofence = FactoryGirl.create(:geofence, name: 'Geofence')

        reading_one = FactoryGirl.create(
          :reading,
          device: device,
          recorded_at: "2017-11-09 10:22:00",
          location: location,
          geofence: geofence
        )

        reading_two = FactoryGirl.create(
          :reading,
          device: device,
          recorded_at: "2017-11-09 10:52:00",
          location: location,
          geofence: geofence
        )

        reading_three = FactoryGirl.create(
          :reading,
          device: device,
          recorded_at: "2017-11-10 10:52:00",
          location: location,
          geofence: geofence
        )

        FactoryGirl.create(:digital_sensor_reading, reading: reading_one)
        FactoryGirl.create(:digital_sensor_reading, reading: reading_two)
      end

      should 'generate the sensors report' do
        assert_equal(read_fixture('sensors_report.txt').join, @scheduled_report.sensors)
      end
    end

    context '#idle' do
      setup do
        account = FactoryGirl.create(:account)

        device = FactoryGirl.create(:active_device, account: account, name: 'Device Test')

        @scheduled_report = FactoryGirl.create(
          :scheduled_report,
          scheduled_for: Time.new(2017, 11, 11),
          report_params: { 'group_id' => '', 'device_id' => '', 'account_id' => account.id }
        )

        location = FactoryGirl.create(:location)
        geofence = FactoryGirl.create(:geofence, name: 'Geofence')

        reading_one = FactoryGirl.create(
          :reading,
          device: device,
          recorded_at: "2017-11-10 10:22:00",
          location: location,
          geofence: geofence,
          speed: 60
        )

        reading_two = FactoryGirl.create(
          :reading,
          device: device,
          recorded_at: "2017-11-10 10:52:00",
          location: location,
          geofence: geofence,
          speed: 70
        )

        FactoryGirl.create(
          :idle_event,
          device: device,
          start_reading: reading_one,
          end_reading: reading_two,
          duration: 200,
          started_at: "2017-11-9 10:22:00"
        )

        FactoryGirl.create(
          :idle_event,
          device: device,
          start_reading: reading_two,
          duration: 250,
          started_at: "2017-11-9 10:52:00"
        )
      end

      should 'generate the idle report' do
        assert_equal(read_fixture('idle_report.txt').join, @scheduled_report.idle)
      end
    end

    context '#maintenance' do
      setup do
        account = FactoryGirl.create(:account)

        device_one = FactoryGirl.create(:active_device, account: account, name: 'Device 1')
        device_two = FactoryGirl.create(:active_device, account: account, name: 'Device 2')
        device_three = FactoryGirl.create(:active_device, account: account, name: 'Device 3')

        @scheduled_report = FactoryGirl.create(
          :scheduled_report,
          scheduled_for: Time.new(2017, 11, 11),
          report_params: { 'group_id' => '', 'device_id' => '', 'account_id' => account.id }
        )

        FactoryGirl.create(
          :mileage_maintenance,
          device: device_one,
          completed_at: Time.new(2017, 11, 10),
          created_at: Time.new(2017, 11, 9),
          description_task: 'Maintenance 1'
        )

        FactoryGirl.create(
          :mileage_maintenance,
          device: device_two,
          completed_at: Time.new(2017, 11, 10),
          created_at: Time.new(2017, 11, 9),
          description_task: 'Maintenance 2'
        )

        FactoryGirl.create(
          :mileage_maintenance,
          device: device_three,
          completed_at: Time.new(2017, 11, 10),
          created_at: Time.new(2017, 11, 9),
          description_task: 'Maintenance 3'
        )
      end

      should 'generate the maintenance report' do
        assert_equal(read_fixture('maintenance_report.txt').join, @scheduled_report.maintenance)
      end
    end

    context '#speeding' do
      setup do
        account = FactoryGirl.create(:account)

        device = FactoryGirl.create(:active_device, account: account, name: 'Device One')

        @scheduled_report = FactoryGirl.create(
          :scheduled_report,
          scheduled_for: Time.new(2017, 11, 11),
          report_params: { 'group_id' => '', 'device_id' => '', 'account_id' => account.id }
        )

        location = FactoryGirl.create(:location)
        geofence = FactoryGirl.create(:geofence, name: 'Geofence')

        FactoryGirl.create(
          :reading,
          device: device,
          recorded_at: "2017-11-9 21:00",
          event_type: EventTypes::Speed,
          location: location,
          geofence: geofence,
          speed: 60
        )

        FactoryGirl.create(
          :reading,
          device: device,
          recorded_at: "2017-11-9 21:01",
          event_type: EventTypes::Speed,
          location: location,
          geofence: geofence,
          speed: 70
        )
      end

      should 'generate the speeding report' do
        assert_equal(read_fixture('speeding_report.txt').join, @scheduled_report.speeding)
      end
    end

    context '#location' do
      setup do
        account = FactoryGirl.create(:account)

        device_one = FactoryGirl.create(:active_device, account: account, name: 'Device 1')
        device_two = FactoryGirl.create(:active_device, account: account, name: 'Device 2')

        @scheduled_report = FactoryGirl.create(
          :scheduled_report,
          scheduled_for: Time.new(2017, 11, 11),
          report_params: { 'group_id' => '', 'device_id' => '', 'account_id' => account.id }
        )

        location = FactoryGirl.create(:location)
        geofence = FactoryGirl.create(:geofence, name: 'Geofence')

        FactoryGirl.create(
          :reading,
          device: device_one,
          recorded_at: "2017-11-9 21:00",
          geofence_event_type: "enter",
          location: location,
          geofence: geofence,
          speed: 60
        )

        FactoryGirl.create(
          :reading,
          device: device_two,
          recorded_at: "2017-11-9 21:01",
          geofence_event_type: "exit",
          location: location,
          geofence: geofence,
          speed: 70
        )
      end

      should 'generate the location report' do
        assert_equal(read_fixture('location_report.txt').join, @scheduled_report.location)
      end
    end
  end

  private

  def read_fixture(report_type)
    IO.readlines(File.join(Rails.root, 'test', 'fixtures', 'scheduled_reports', report_type))
  end
end
