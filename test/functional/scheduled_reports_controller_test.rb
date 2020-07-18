require 'test_helper'

class ScheduledReportsControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  fixtures :users, :readings, :device_profiles, :devices, :accounts

  module RequestExtensions
    def server_name
      "yoohoodilly"
    end

    def path_info
      "asdf"
    end
  end

  setup do
    @request.extend(RequestExtensions)
    sign_in users(:dennis)
  end

  context 'index' do
    should 'redirect to schedule reports list' do
      get :index, {}
      assert_redirected_to '/reports/scheduled_reports'
    end
  end

  context 'new' do
    should 'respond properly' do
      get :new, {}
      assert_response :success
    end

    context 'state milege report' do
      context 'enabled' do
        setup do
          current_user.account.update_attribute(:show_state_mileage_report, true)
        end

        should 'show State Mileage type on type report select' do
          get :new
          assert_select 'select#scheduled_report_report_type option[value="state_mileage"]', { count: 1 }
        end
      end

      context 'disabled' do
        setup do
          current_user.account.update_attribute(:show_state_mileage_report, false)
        end

        should 'do not show State Mileage type on type report select' do
          get :index
          assert_select 'select#scheduled_report_report_type option[value="state_mileage"]', { count: 0 }
        end
      end
    end
  end

  context 'create' do
    should 'redirect to scheduled reports list' do
      assert_difference 'ScheduledReport.count' do
        get :create, { "scheduled_report" => { "scheduled_for(1i)" => "2012", "scheduled_for(4i)" => "8", "scheduled_for(2i)" => "3", "scheduled_for(3i)" => "3", "report_type" => "group_trip", "report_name" => "Marketing", "recur_interval" => "1.week", "report_span_units" => "Weeks", "report_params" => { "device_id" => "46", "group_id" => "" }, "report_span_value" => "1", "recur" => "1" } }
      end
      assert_redirected_to '/reports/scheduled_reports'
      assert_equal 'Report Created', flash[:success]
    end

    context 'without name' do
      should 'show flash error message' do
        get :create, { "scheduled_report" => { "scheduled_for(1i)" => "2012", "scheduled_for(4i)" => "8", "scheduled_for(2i)" => "3", "scheduled_for(3i)" => "3", "report_type" => "group_trip", "recur_interval" => "1.week", "report_span_units" => "Weeks", "report_params" => { "device_id" => "46", "group_id" => "" }, "report_span_value" => "1", "recur" => "1" } }

        assert_match /Report name can\'t be blank/, flash[:error]
      end
    end

    context 'create too many' do
      setup do
        sign_in users(:demo)
      end

      should 'show flash error message' do
        (2..(BackgroundReport::LIMIT_PER_USER + 2)).each do |x|
          get :create, { "scheduled_report" => { "scheduled_for(1i)" => "2012", "scheduled_for(4i)" => "9", "scheduled_for(2i)" => "4", "scheduled_for(3i)" => "4", "report_type" => "group_trip", "report_name" => "Marketing_#{x}", "recur_interval" => "1.week", "report_span_units" => "Weeks", "report_params" => { "device_id" => "46", "group_id" => "" }, "report_span_value" => "1", "recur" => "1"  } }
        end

        assert_match /Each user may have at most #{BackgroundReport::LIMIT_PER_USER} pending scheduled reports/, flash[:error]
      end
    end
  end

  private

  def current_user
    users(:dennis)
  end
end
