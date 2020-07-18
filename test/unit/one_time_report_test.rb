require 'test_helper'

class OneTimeReportTest < ActiveSupport::TestCase
  context 'adjust_parameters' do
    setup do
      @report = OneTimeReport.new(scheduled_for: nil, recur: nil, report_type: 'state_mileage')
      DateTime.stubs(now: DateTime.parse('2013-08-28 11:03:00'))
    end

    should 'set to DateTime.now the scheduled_for field' do
      @report.adjust_parameters
      assert_equal DateTime.now, @report.scheduled_for
      DateTime.unstub(:now)
    end

    should 'set to false the recur field' do
      @report.adjust_parameters
      assert_equal false, @report.recur
    end
  end
end
