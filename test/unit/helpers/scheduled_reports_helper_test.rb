require 'test_helper'

class ScheduledReportsHelperTest < ActionView::TestCase
  fixtures :users, :accounts

  context 'my_hour_select method' do
    should 'return option 0 as selected when called without arguments' do
      assert_match /option value='0' selected/, my_hour_select
    end

    should 'return option 3 as selected when called with second param as 3' do
      assert_match /option value='3' selected/, my_hour_select('', 3)
    end

    should 'return select name as name when called with first argument as name' do
      assert_match /select name='name'/, my_hour_select('name', 1)
    end
  end

  context 'report_span_options' do
    context 'no state_mileage report' do
      setup do
        @report = ScheduledReport.new(report_type: 'stops')
      end

      should 'not include "3 Months" option' do
        assert_equal ScheduledReport::REPORT_SPANS.collect { |x| ["1 #{x.singularize}", "1.#{x}"] }, report_span_options(@report)
      end
    end

    context 'state_mileage report' do
      setup do
        @report = ScheduledReport.new(report_type: 'state_mileage')
      end

      should 'include "3 Months" option' do
        options = ScheduledReport::REPORT_SPANS.collect { |x| ["1 #{x.singularize}", "1.#{x}"] }
        options << ['3 Months', '3.Months']
        assert_equal options, report_span_options(@report)
      end
    end
  end

  context 'report_span_selected_option' do
    setup do
      @report = ScheduledReport.new(report_span_value: 1, report_span_units: 'Days')
    end

    should 'return the report span value and unit formatted' do
      assert_equal '1.Days', report_span_selected_option(@report)
    end
  end

  context 'report_type_options' do
    setup do
      @user = users(:dennis)
    end

    context 'with state mileage report visibility' do
      setup do
        @user.account.update_attribute(:show_state_mileage_report, true)
      end

      should 'return all the report types' do
        options = [['Fleet Start/Stop', 'group_trip'],
                   ['Stops', 'stops'],
                   ['Speeding', 'speeding'],
                   ['Idle', 'idle'],
                   ['Maintenance', 'maintenance'],
                   ['Location', 'location'],
                   ['Sensors', 'sensors'],
                   ['State Mileage', 'state_mileage']]

        assert_equal options, report_type_options(@user.account.show_state_mileage_report?)
      end
    end

    context 'without state mileage report visibility' do
      setup do
        @user.account.update_attribute(:show_state_mileage_report, false)
      end

      should 'return all the report types but state mileage type' do
        options = [['Fleet Start/Stop', 'group_trip'],
                   ['Stops', 'stops'],
                   ['Speeding', 'speeding'],
                   ['Idle', 'idle'],
                   ['Maintenance', 'maintenance'],
                   ['Location', 'location'],
                   ['Sensors', 'sensors']]

        assert_equal options, report_type_options(@user.account.show_state_mileage_report?)
      end
    end
  end

  private

  def current_user
    @user
  end
end
