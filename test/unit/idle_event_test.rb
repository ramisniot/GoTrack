require 'test_helper'

class IdleEventTest < ActiveSupport::TestCase
  fixtures :idle_events

  # TODO revisit jobs
  # context 'start_jobs_for_time_exceed' do
  #   context 'device without idle alert threshold' do
  #     setup do
  #       @device = FactoryGirl.create(:device, idle_threshold: nil)
  #     end
  #
  #     should 'not enqueue job' do
  #       Delayed::Job.expects(:enqueue).never
  #       FactoryGirl.create(:idle_event, device: @device)
  #     end
  #   end
  #
  #   context 'device with idle alert threshold' do
  #     context 'idle alert is zero' do
  #       setup do
  #         @device = FactoryGirl.create(:device, idle_threshold: 0)
  #       end
  #       should 'not enqueue job' do
  #         Delayed::Job.expects(:enqueue).never
  #         FactoryGirl.create(:idle_event, device: @device)
  #       end
  #     end
  #
  #     context 'idle alert threshold is greater than zero' do
  #       setup do
  #         @device = FactoryGirl.create(:device, idle_threshold: 300)
  #       end
  #       should 'enqueue job' do
  #         Delayed::Job.expects(:enqueue).once
  #         FactoryGirl.create(:idle_event, device: @device)
  #       end
  #     end
  #   end
  # end

  context 'exceed_threshold_time' do
    setup do
      now = Time.now
      Time.stubs(:now).returns(now)
    end

    context 'when end_reading_id is set' do
      setup do
        @device = FactoryGirl.build(:device, idle_threshold: 10)
        reading = FactoryGirl.build(:reading)
        @idle_event = FactoryGirl.build(:idle_event, device: @device, started_at: Time.now - 3.seconds, end_reading: reading)
      end

      context 'duration is nil' do
        setup do
          @idle_event.duration = nil
        end

        should 'return false' do
          refute @idle_event.exceeded_threshold?
        end
      end

      context 'duration is more than idle threshold' do
        setup do
          @idle_event.duration = 12
        end

        should 'return true' do
          assert @idle_event.exceeded_threshold?
        end
      end

      context 'duration is less than idle threshold' do
        setup do
          @idle_event.duration = 8
        end

        should 'return false' do
          refute @idle_event.exceeded_threshold?
        end
      end
    end

    context 'when end_reading_id is not set' do
      context 'when idle_event is in progress' do
        setup do
          @device = FactoryGirl.build(:device)
          @idle_event = FactoryGirl.build(:idle_event, device: @device, started_at: Time.now - 3.seconds, end_reading_id: nil)
        end

        context 'when idle_threshold is not reached' do
          setup do
            @device.idle_threshold = 2000
          end

          should 'return false' do
            assert_not @idle_event.exceeded_threshold?
          end
        end

        context 'when idle_threshold is reached' do
          setup do
            @device.idle_threshold = 1
          end
          should 'return true' do
            assert @idle_event.exceeded_threshold?
          end
        end
      end
    end

    context 'when idle_event is not in progress' do
      setup do
        @device = FactoryGirl.build(:device)
        @idle_event = FactoryGirl.build(:idle_event, device: @device, started_at: Time.now - 3.seconds, end_reading: FactoryGirl.build(:reading))
      end
      context 'when idle_threshold is not reached' do
        setup do
          @device.idle_threshold = 2000
        end

        should 'return false' do
          assert_not @idle_event.exceeded_threshold?
        end
      end

      context 'when idle_threshold is reached' do
        setup do
          @device.idle_threshold = 1
        end

        should 'return false' do
          assert_not @idle_event.exceeded_threshold?
        end
      end
    end
  end

  context 'notify_time_exceeded' do
    setup do
      @device = FactoryGirl.create(:device, idle_threshold: 1)
      @user = FactoryGirl.create(:user, account: @device.account, enotify: User::NOTIFICATIONS[:all_in_account])
      @idle_event = FactoryGirl.create(:idle_event, device: @device, started_at: Time.now - 3.seconds, end_reading_id: nil)
    end

    context 'user is subscribed to idle notifications' do
      setup do
        @user.update_attribute(:subscribed_notifications, [:idling])
      end

      # TODO revisit jobs
      # should 'notify related user' do
      #   mail = mock()
      #   mail.stubs(:deliver).returns(nil)
      #   IdleAlertMailer.expects(:idle_extended_alert_mail).returns(mail)
      #
      #   @idle_event.notify_time_exceeded
      # end
    end

    context 'user is not subscribed to idle notifications' do
      setup do
        @user.update_attribute(:subscribed_notifications, [])
      end

      # TODO revisit jobs
      # should 'not notify related user' do
      #   mail = mock()
      #   mail.stubs(:deliver).returns(nil)
      #   IdleAlertMailer.expects(:idle_extended_alert_mail).returns(mail).never
      #
      #   @idle_event.notify_time_exceeded
      # end
    end
  end

  context 'in_progress?' do
    setup do
      @idle_event = FactoryGirl.build(:idle_event)
    end

    context 'end_reading is nil' do
      setup do
        @idle_event.end_reading = nil
      end

      should 'return true' do
        assert @idle_event.in_progress?
      end
    end

    context 'end_reading is not nil' do
      setup do
        @idle_event.end_reading = FactoryGirl.build(:reading)
      end

      should 'return false' do
        assert_not @idle_event.in_progress?
      end
    end
  end
end
