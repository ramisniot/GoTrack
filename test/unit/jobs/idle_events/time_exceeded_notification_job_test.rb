# require 'test_helper'

# class IdleEvents::TimeExceededNotificationJobTest < ActionController::TestCase
  # TODO revisit stompers/jobs...
  # context 'initialize' do
  #   setup do
  #     @device = FactoryGirl.create(:device)
  #     @idle_event = FactoryGirl.create(:idle_event, device: @device)
  #     @job = IdleEvents::TimeExceededNotificationJob.new(@idle_event)
  #   end
  #
  #   should 'not create a Delayed::Job' do
  #     assert_equal 0, Delayed::Job.where(entity: @idle_event).where("handler like '%#{@device.class}%'").size
  #   end
  #
  #   should 'use idle_event_time_exceeded_notification queue' do
  #     assert_equal 'idle_event_time_exceeded_notification', @job.queue_name
  #   end
  # end
  #
  # context 'queued' do
  #   setup do
  #     @device = FactoryGirl.create(:device)
  #     @idle_event = FactoryGirl.create(:idle_event, device: @device)
  #     job = IdleEvents::TimeExceededNotificationJob.new(@idle_event)
  #     Delayed::Job.enqueue(job, run_at: Time.now + 50)
  #   end
  #
  #   should 'create a idle event delayed job for the device' do
  #     assert_equal 1, Delayed::Job.where(entity: @idle_event).where("handler like '%#{@device.class}%'").size
  #   end
  #
  #   should 'set entity as @idle_event' do
  #     assert_equal @idle_event, Delayed::Job.where(entity: @idle_event).where("handler like '%#{@device.class}%'").first.entity
  #   end
  # end
  #
  # context 'perform' do
  #   context 'without raising an error' do
  #     setup do
  #       @device = FactoryGirl.create(:device, idle_threshold: 10)
  #       @idle_event = FactoryGirl.create(:idle_event, device: @device, end_reading_id: nil)
  #       @job = IdleEvents::TimeExceededNotificationJob.new(@idle_event)
  #     end
  #
  #     context 'idle event threshold has been exceeded' do
  #       setup do
  #         @idle_event.stubs(:exceeded_threshold?).returns(true)
  #       end
  #
  #       should 'notify time exceeded' do
  #         @idle_event.expects(:notify_time_exceeded).once
  #         @job.perform
  #       end
  #     end
  #
  #     context 'idle_event time has not been exceeded' do
  #       setup do
  #         @idle_event.stubs(:exceeded_threshold?).returns(false)
  #       end
  #
  #       should 'not notify time exceeded' do
  #         @idle_event.expects(:notify_time_exceeded).never
  #         @job.perform
  #       end
  #     end
  #
  #     context 'idle_threshold has changed' do
  #       setup do
  #         @device.update_attributes(idle_threshold: 20)
  #         @idle_event.stubs(:exceeded_threshold?).returns(true)
  #       end
  #
  #       should 'not notify time exceeded' do
  #         @idle_event.expects(:notify_time_exceeded).never
  #         @job.perform
  #       end
  #     end
  #
  #     context 'idle_event has finished' do
  #       context 'duration is nil' do
  #         setup do
  #           @idle_event.update_attributes!(end_reading: FactoryGirl.create(:reading), duration: nil)
  #         end
  #
  #         should 'not notify time exceeded' do
  #           @idle_event.expects(:notify_time_exceeded).never
  #           @job.perform
  #         end
  #       end
  #
  #       context 'duration is more than idle_threshold' do
  #         setup do
  #           @idle_event.update_attributes!(end_reading: FactoryGirl.create(:reading), duration: 11)
  #         end
  #
  #         should 'notify time exceeded' do
  #           @idle_event.expects(:notify_time_exceeded).once
  #           @job.perform
  #         end
  #       end
  #
  #       context 'duration is less than idle_threshold' do
  #         setup do
  #           @idle_event.update_attributes!(end_reading: FactoryGirl.create(:reading), duration: 8)
  #         end
  #
  #         should 'not notify time exceeded' do
  #           @idle_event.expects(:notify_time_exceeded).never
  #           @job.perform
  #         end
  #       end
  #     end
  #   end
  #
  #   context 'raising an error' do
  #     setup do
  #       @device = FactoryGirl.create(:device, idle_threshold: nil)
  #       @idle_event_2 = FactoryGirl.create(:idle_event, device: @device, end_reading_id: nil)
  #       job = IdleEvents::TimeExceededNotificationJob.new(@idle_event_2)
  #       Delayed::Job.enqueue(job, run_at: Time.now + 3)
  #     end
  #
  #     should 'mark the job as failed and re-enqueue it only once' do
  #       jobs = Delayed::Job.where(entity: @idle_event_2)
  #       assert_equal 1, jobs.count
  #
  #       assert_difference 'Delayed::Job.where(entity: @idle_event_2).count' do
  #         job = Delayed::Job.where(entity: @idle_event_2).first
  #         worker = Delayed::Worker.new
  #         worker.run job
  #       end
  #
  #       failed_jobs = Delayed::Job.where(entity: @idle_event_2).where.not(failed_at: nil)
  #       new_jobs = Delayed::Job.where(entity: @idle_event_2).where(failed_at: nil)
  #       assert_equal 1, failed_jobs.count
  #       assert_equal 1, new_jobs.count
  #
  #       assert_match /undefined method/, failed_jobs.first.last_error
  #       assert new_jobs.first.run_at > failed_jobs.first.run_at
  #     end
  #   end
  # end
# end
