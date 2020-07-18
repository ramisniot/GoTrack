require 'test_helper'

class BackgroundReportTest < ActiveSupport::TestCase
  context 'enqueue_scheduled_report' do
    setup do
      now = DateTime.now
      DateTime.stubs(now: now)

      @user = FactoryGirl.create(:user)
    end

    teardown do
      DateTime.unstub(:now)
    end

    context 'scheduled report' do
      setup do
        @scheduled_report = ScheduledReport.new(
          report_name: 'R1',
          report_type: 'trip',
          user: @user,
          scheduled_for: DateTime.now + 10.days
        )
      end

      context 'after create' do
        should 'enqueue the report to scheduled report stomper' do
          @scheduled_report.id = 111
          delay_in_secs = 10 * 24 * 3600;

          ScheduledReportsWorker.expects(:perform_in).with(delay_in_secs.seconds, { id: 111 })
          @scheduled_report.save
        end
      end

      context 'after update' do
        setup do
          @scheduled_report.save
        end

        should 'not enqueue if scheduled_for did not change' do
          ScheduledReportsWorker.expects(:perform_in).never
          @scheduled_report.update_attributes(report_name: 'change test')
        end

        should 'enqueue if scheduled_for changed without changing day' do
          delay_in_secs = @scheduled_report.delay_in_seconds + 10 * 60

          ScheduledReportsWorker.expects(:perform_in).with(delay_in_secs, { id: @scheduled_report.id })
          @scheduled_report.update_attributes(scheduled_for: @scheduled_report.scheduled_for + 10.minutes)
        end

        should 'enqueue if scheduled_for changed' do
          delay_in_secs = 9 * 24 * 3600

          ScheduledReportsWorker.expects(:perform_in).with(delay_in_secs, { id: @scheduled_report.id })
          @scheduled_report.update_attributes(scheduled_for: DateTime.now + 9.days)
        end
      end
    end

    context 'one time report' do
      setup do
        @one_time_report = OneTimeReport.new(
          report_name: 'R2',
          report_type: 'state_mileage',
          user: @user,
          scheduled_for: DateTime.now
        )
      end

      context 'after create' do
        should 'enqueue the report to scheduled report stomper' do
          @one_time_report.id = 111
          ScheduledReportsWorker.expects(:perform_in).with(0, { id: @one_time_report.id })
          @one_time_report.save
        end
      end
    end
  end

  context 'delay_in_seconds' do
    setup do
      DateTime.stubs(now: DateTime.parse('2013-08-28 11:03:00'))
      @report = BackgroundReport.new scheduled_for: DateTime.parse('2013-08-28 11:04:00')
    end

    should 'calculate the correct delay' do
      assert_equal 60, @report.delay_in_seconds
      DateTime.unstub(:now)
    end
  end
end
