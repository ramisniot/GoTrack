require 'test_helper'

class IdleTimeExceededNotificationWorkerTest < ActiveSupport::TestCase
  test 'perform_async should enqueue a job' do
    assert_equal 0, IdleTimeExceededNotificationWorker.jobs.size
    IdleTimeExceededNotificationWorker.perform_async(1)
    assert_equal 1, IdleTimeExceededNotificationWorker.jobs.size

    Sidekiq::Worker.clear_all
  end

  test 'perform should call notify_time_exceeded on idle event' do
    mock = Minitest::Mock.new

    def mock.exceeded_threshold?
      true
    end

    def mock.id
      1
    end

    def mock.device
      nil
    end

    mock.expect :notify_time_exceeded, nil

    IdleEvent.stub :find_by, mock do
      IdleTimeExceededNotificationWorker.new.perform(mock.id)
    end

    assert_mock mock

    Sidekiq::Worker.clear_all
  end
end
