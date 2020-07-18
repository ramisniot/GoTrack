require 'test_helper'

class OneTimeReportsControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  fixtures :users, :accounts

  setup do
    @user = users(:nick)
    sign_in users(:nick)
  end

  context 'with state mileage report visibility' do
    setup do
      @user.account.update_attribute(:show_state_mileage_report, true)
    end

    context 'new' do
      should 'respond properly' do
        get :new
        assert_response :success
      end
    end

    context 'create' do
      should 'create the report and redirect to scheduled reports list' do
        assert_difference 'ScheduledReport.count' do
          get :create, { 'one_time_report' => { 'report_name' => 'Test1', 'report_type' => 'state_mileage', 'report_params' => { 'device_id' => '46', 'group_id' => '' } } }
        end
        assert_redirected_to action_reports_path(action: 'scheduled_reports')
        assert_equal 'The report is being completed', flash[:success]
      end

      context 'without name' do
        should 'show flash error message' do
          get :create, { 'one_time_report' => { 'report_params' => { 'device_id' => '', 'group_id' => '' }, 'report_type' => 'state_mileage' } }

          assert_equal 'Report name can\'t be blank', flash[:error]
        end
      end

      context 'create too many' do
        setup do
          @user = users(:ken)
          @user.account.update_attribute(:show_state_mileage_report, true)
          sign_in users(:ken)
        end

        should 'show flash error message' do
          (1..(BackgroundReport::LIMIT_PER_USER + 1)).each do |x|
            get :create, { 'one_time_report' => { 'report_name' => "Test_#{x}", 'from(3i)' => '25', 'from(2i)' => '4', 'from(1i)' => '2014', 'from(4i)' => '12', 'from(5i)' => '0', 'to(3i)' => '25', 'to(2i)' => '4', 'to(1i)' => '2014', 'to(4i)' => '12', 'to(5i)' => '0', 'report_type' => 'state_mileage', 'report_params' => { 'group_id' => '', 'device_id' => '' } } }
          end

          assert_equal "Each user may have at most #{BackgroundReport::LIMIT_PER_USER} pending scheduled reports", flash[:error]
        end
      end
    end
  end

  context 'without state mileage report visibility' do
    setup do
      @user.account.update_attribute(:show_state_mileage_report, false)
    end

    context 'new' do
      should 'redirect to reports index' do
        get :new
        assert_redirected_to reports_path
      end
    end

    context 'create' do
      should 'redirect to reports index' do
        get :create, { 'one_time_report' => { 'report_name' => 'Test', 'report_params' => { 'device_id' => '46', 'group_id' => '' } } }
        assert_redirected_to reports_path
      end
    end
  end
end
