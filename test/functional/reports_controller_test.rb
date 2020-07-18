require 'test_helper'

class ReportsControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  module RequestExtensions
    def server_name
      "yoohoodilly"
    end

    def path_info
      "asdf"
    end
  end

  setup do
    @account = FactoryGirl.create(:account)
    @user = FactoryGirl.create(:user, account: @account)
    @device = FactoryGirl.create(:device_a, account: @account)
    sign_in @user
  end

  context 'GET index' do
    context 'account has provisioned devices' do
      should 'return index page with all devices' do
        get :index
        assert_response :success
      end
    end

    context 'group_id passed as a parameter' do
      should 'return index page with all devices' do
        get :index, { group_id: 1 }
        assert_response :success
      end
    end
  end

  context 'GET scheduled_reports' do
    context 'account has scheduled reports' do
      setup do
        @scheduled_report = FactoryGirl.create(:scheduled_report_uncompleted, user: @user)
      end

      should 'return scheduled reports page' do
        get :scheduled_reports
        assert_response :success
        assert assigns(:scheduled_reports).any?
      end
    end

    context 'user does not have show state milage reports activated' do
      setup do
        @account.show_state_mileage_report = false
        @scheduled_report = FactoryGirl.create(:scheduled_report_uncompleted, user: @user)
      end

      should 'return scheduled reports page' do
        get :scheduled_reports
        assert_response :success
        assert assigns(:scheduled_reports).any?
      end
    end
  end

  context 'GET trip' do
    context 'device has trip events and legs' do
      setup do
        @trip_event = FactoryGirl.create(:trip_event, device: @device)
        @trip_leg = FactoryGirl.create(:trip_leg, trip_event: @trip_event, device: @device)
      end

      should 'return device trip events and legs' do
        get :trip, { id: @device.id, start_date: 2.days.ago, end_date: (DateTime.now.utc + 2.days) }
        assert_response :success
        assert assigns(:trip_legs).any?
      end
    end

    context 'device does not have trip events' do
      should 'not return any trip events or legs' do
        get :trip, { id: @device.id, start_date: 2.days.ago, end_date: (DateTime.now.utc + 2.days) }
        assert_response :success
        assert assigns(:trip_legs).empty?
      end
    end

    context 'device does not exist' do
      should 'redirect to /user/sign_out' do
        get :trip, { id: 12345678, start_date: 2.days.ago, end_date: (DateTime.now.utc + 2.days) }
        assert_redirected_to '/user/sign_out'
      end
    end
  end

  context 'GET trip_detail' do
    context 'device has trip events' do
      setup do
        @trip_event = FactoryGirl.create(:trip_event, device: @device)
      end

      should 'return trip event details' do
        get :trip_detail, { id: @trip_event.id }
        assert_response :success
      end
    end
  end

  context 'GET leg_detail' do
    context 'existing leg detail on trip event' do
      setup do
        @trip_event = FactoryGirl.create(:trip_event, device: @device)
        @trip_leg = FactoryGirl.create(:trip_leg, trip_event: @trip_event)
      end

      should 'return leg details' do
        get :leg_detail, { id: @trip_leg.id }
        assert_response :success
        assert_not_nil assigns(:leg)
      end
    end

    context 'no trip leg associated to trip event' do
      setup do
        @trip_event = FactoryGirl.create(:trip_event, device: @device)
      end

      should 'return no leg detail' do
        get :leg_detail, { id: 101 }
        assert_response :success
        assert_nil assigns(:leg)
      end
    end
  end

  context 'GET all' do
    context 'device has readings' do
      setup do
        @reading = FactoryGirl.create(:reading, device: @device)
      end

      should 'enque readings from device for reverse geocoding' do
        get :all, { id: @device.id }
        assert_response :success
        assert assigns(:readings).any?
      end
    end
  end

  context 'GET maintenance' do
    context 'existing maintenances on device' do
      setup do
        @maintenance = FactoryGirl.create(:completed_maintenance, device: @device)
      end

      should 'return maintenances for device' do
        get :maintenance, { id: @device.id, start_date: 2.days.ago, end_date: (DateTime.now.utc + 2.days) }
        assert_response :success
        assert assigns(:maintenances).any?
      end
    end

    context 'no maintenances associated to device' do
      setup do
        @maintenance = FactoryGirl.create(:maintenance)
      end

      should 'return empty maintenances' do
        get :maintenance, { id: @device.id, start_date: 2.days.ago, end_date: (DateTime.now.utc + 2.days) }
        assert_response :success
        assert assigns(:maintenances).empty?
      end
    end
  end

  context 'GET speeding' do
    context 'device has speeding readings on history' do
      setup do
        @reading = FactoryGirl.create(:reading, device: @device)
      end

      should 'return speeding readings' do
        get :speeding, { id: @device.id, start_date: Time.zone.now }
        assert_response :success
        assert assigns(:readings).any?
      end
    end

    context 'no speeding readings associated to device' do
      should 'return no speeding readings' do
        get :speeding, { id: @device.id, start_date: Time.zone.now }
        assert_response :success
        assert assigns(:readings).empty?
      end
    end
  end

  context 'GET stop' do
    context 'device has authorized stops events reports' do
      setup do
        @reading = FactoryGirl.create(:reading_a_1, device: @device)
        @stop_event = FactoryGirl.create(:stop_event_1, device: @device, start_reading_id: @reading.id)
      end

      should 'return stop reports' do
        get :stop, { id: @device.id, start_date: @reading.recorded_at }
        assert_equal 1, assigns(:record_count)
        assert_response :success
      end
    end
  end

  context 'GET idle' do
    context 'device has authorized stops reports' do
      setup do
        @reading = FactoryGirl.create(:reading_a_1, device: @device)
        @idle_event = FactoryGirl.create(:recent_event_update2, device: @device, start_reading_id: @reading.id)
      end

      should 'return idle reports' do
        get :idle, { id: @device.id, start_date: @reading.recorded_at }
        assert_equal 1, assigns(:record_count)
        assert_response :success
      end
    end
  end

  context 'GET geofence' do
    context 'device has geofence reports' do
      setup do
        @reading = FactoryGirl.create(:reading_geofence_exit, device: @device)
        @idle_event = FactoryGirl.create(:recent_event_update2, device: @device, start_reading_id: @reading.id)
      end

      should 'return geofence reports' do
        get :geofence, { id: @device.id, start_date: @reading.recorded_at }
        assert_response :success
        readings = assigns(:readings)
        assert_equal 1, assigns(:record_count)
      end
    end

    context 'invalid date passed' do
      setup do
        @reading = FactoryGirl.create(:reading_geofence_exit, device: @device)
        @idle_event = FactoryGirl.create(:recent_event_update2, device: @device, start_reading_id: @reading.id)
      end

      should 'return flash error message with invalid date' do
        get :geofence, { id: @device.id, start_date: 'date' }
        assert_equal 'Invalid date', flash[:error]
      end
    end

    context 'invalid device id passed' do
      setup do
        @reading = FactoryGirl.create(:reading_geofence_exit, device: @device)
        @idle_event = FactoryGirl.create(:recent_event_update2, device: @device, start_reading_id: @reading.id)
      end

      should 'redirect to user/sign_out' do
        get :geofence, { id: 121122112 }
        assert_redirected_to '/user/sign_out'
      end
    end
  end

  context 'GET all_events' do
    context 'device has events on history' do
      setup do
        @reading = FactoryGirl.create(:reading_geofence_exit, device: @device)
        @idle_event = FactoryGirl.create(:recent_event_update2, device: @device, start_reading_id: @reading.id)
      end

      should 'return all events associated to device' do
        get :all_events, { id: @device.id }
        assert_response :success
        assert assigns(:readings).any?
      end
    end

    context 'device does not have events on history' do
      should 'return no events associated to device' do
        get :all_events, { id: @device.id }
        assert_response :success
        assert assigns(:readings).empty?
      end
    end
  end

  context 'GET export' do
    context 'export all' do
      setup do
        @reading = FactoryGirl.create(:reading_geofence_exit, device: @device)
        @idle_event = FactoryGirl.create(:recent_event_update2, device: @device, start_reading_id: @reading.id)
      end

      should 'export all data to csv' do
        get :export, { id: @device.id, type: 'all', start_date: "2008-05-24", end_date: "2020-06-26" }
        assert_response :success
        assert_kind_of String, @response.body
        output = StringIO.new
      end
    end

    context 'export stop' do
      setup do
        @reading = FactoryGirl.create(:reading_geofence_exit, device: @device)
        @stop_event = FactoryGirl.create(:stop_event_1, device: @device, start_reading_id: @reading.id)
      end

      should 'export all stops to csv' do
        get :export, { id: @device.id, type: 'stop', start_date: "2008-05-24", end_date: "2020-06-25" }
        assert_response :success
      end
    end

    context 'export geofence' do
      setup do
        @reading = FactoryGirl.create(:reading_geofence_exit, device: @device)
        @stop_event = FactoryGirl.create(:stop_event_1, device: @device, start_reading_id: @reading.id)
      end

      should 'export all geofence events to csv' do
        get :export, { id: @device.id, type: 'geofence', start_date: "2008-05-24", end_date: "2020-06-25" }
        assert_response :success
      end
    end

    context 'export maintenance' do
      setup do
        @reading = FactoryGirl.create(:reading_geofence_exit, device: @device)
        @stop_event = FactoryGirl.create(:stop_event_1, device: @device, start_reading_id: @reading.id)
        @maintenance = FactoryGirl.create(:maintenance, device: @device)
      end

      should 'export all maintenance completed to csv' do
        get :export, { id: @device.id, type: 'maintenance', start_date: 2.day.ago, end_date: (DateTime.now.utc + 2.days) }
        assert_response :success
      end
    end

    context 'export idle' do
      setup do
        @reading = FactoryGirl.create(:reading_geofence_exit, device: @device)
        @stop_event = FactoryGirl.create(:stop_event_1, device: @device, start_reading_id: @reading.id)
      end

      should 'export all idle events to csv' do
        get :export, { id: @device.id, type: 'idle', start_date: "2008-05-24", end_date: "2020-06-25" }
        assert_response :success
      end
    end

    context 'export leg detail' do
      setup do
        @reading = FactoryGirl.create(:reading_geofence_exit, device: @device)
        @trip_event = FactoryGirl.create(:trip_event, device: @device)
        @trip_leg = FactoryGirl.create(:trip_leg, trip_event: @trip_event)
      end

      should 'export all leg details to csv' do
        get :export, { id: @trip_leg.id, type: 'leg_detail', start_date: "2008-05-24", end_date: "2020-06-25" }
        assert_response :success
      end
    end

    context 'export speeding detail' do
      setup do
        @reading = FactoryGirl.create(:reading_geofence_exit, device: @device)
        @trip_event = FactoryGirl.create(:trip_event, device: @device)
        @trip_leg = FactoryGirl.create(:trip_leg, trip_event: @trip_event)
      end

      should 'export all speeding details to csv' do
        get :export, { id: @device.id, type: 'speeding', start_date: "2008-05-24", end_date: "2020-06-25" }
        assert_response :success
      end
    end

    context 'export trip detail' do
      setup do
        @reading = FactoryGirl.create(:reading_geofence_exit, device: @device)
        @trip_event = FactoryGirl.create(:trip_event, device: @device)
        @trip_leg = FactoryGirl.create(:trip_leg, trip_event: @trip_event)
      end

      should 'export all trip details to csv' do
        data = {}
        data[:city] = 'City'
        data[:postal_code] = 11500
        data[:country_long] = 'United States'
        data[:address] = 'Test address 123'
        data[:route] = 'route'
        data[:state_long] = 'California'
        data[:county] = 'US'
        data[:state_short] = 'CL'
        data[:street_number] = '1234'
        QiotApi.stubs(:apply_reverse_geocoding).returns(success: true, data: data)
        get :export, { id: @device.id, type: 'trip', start_date: 2.day.ago, end_date: (DateTime.now.utc + 2.days) }
        assert_response :success
      end
    end
  end

  context 'GET digital_sensor' do
    context 'device does not have readings' do
      setup do
        @digital_sensor = FactoryGirl.create(:digital_sensor, device: @device)
      end

      should 'return empty readings' do
        get :digital_sensor, { id: @device.id }
        assert assigns(:readings).empty?
      end
    end
  end

  private

  def csv_data
    reading1 = readings(:reading24)
    reading2 = readings(:reading26)
    "latitude,longitude,address,speed,direction,altitude,event_type,note,when\r\n#{reading1.latitude},#{reading1.longitude},\"#{reading1.short_address}\",#{reading1.speed},#{reading1.direction},#{reading1.altitude},#{reading1.event_type},#{reading1.note},#{reading1.created_at}\r\n#{reading2.latitude},#{reading2.longitude},\"#{reading2.short_address}\",#{reading2.speed},#{reading2.direction},#{reading2.altitude},#{reading2.event_type},#{reading2.note},#{reading2.created_at}\r\n"
  end

  def current_user
    users(:dennis)
  end
end
