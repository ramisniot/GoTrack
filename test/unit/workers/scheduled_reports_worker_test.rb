require 'test_helper'

class ScheduledReportsWorkerTest < ActiveSupport::TestCase
  context '.perform' do
    setup do
      Sidekiq::Worker.clear_all
      @worker = ScheduledReportsWorker.new
    end

    should 'not raise exception if arguments are invalid' do
      assert_nothing_raised { @worker.perform('GARBAGE') }
    end

    should 'do nothing when scheduled_report does not exist' do
      assert_nothing_raised { @worker.perform({ id: 999 }) }
    end

    should 'call process if scheduled_report exists' do
      @report = FactoryGirl.create(:scheduled_report, user: FactoryGirl.create(:user))

      @report.stubs(:is_outdated?).returns(false)
      ScheduledReport.stubs(not_completed: stub(find_by_id: @report))

      @report.expects(:process).once
      @worker.perform({ id: @report.id })
    end
  end
end
