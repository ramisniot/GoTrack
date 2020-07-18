require 'test_helper'

class OfflineEventEmailObserverTest < ActiveSupport::TestCase
  fixtures :devices, :users, :accounts, :groups, :group_notifications

  def setup
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
  end

  context 'creating an offline event' do
    setup do
      @device = devices(:device1)
      @user = users(:dennis)
      @user.update_attribute(:subscribed_notifications, [:offline])
    end

    context 'with user subscribed at account level' do
      should 'deliver device_offline mail' do
        expect_device_offline_mail_deliver(true)
        OfflineEvent.create device: @device, started_at: DateTime.now
      end

      context 'when user is not subscribed to offline events' do
        setup do
          @user.update_attribute(:subscribed_notifications, [])
        end

        should 'not deliver device_offline mail' do
          expect_device_offline_mail_deliver(false)
          OfflineEvent.create device: @device, started_at: DateTime.now
        end
      end
    end

    context 'with user subscribed at group level' do
      setup do
        @user.update_attributes(enotify: User::NOTIFICATIONS[:all_in_fleet])
      end

      should 'deliver device_offline mail if device belongs to the group' do
        expect_device_offline_mail_deliver(true)
        OfflineEvent.create device: @device, started_at: DateTime.now
      end

      should 'NOT send an email if device does not belongs to the group' do
        assert_no_difference('ActionMailer::Base.deliveries.count') do
          OfflineEvent.create device: devices(:device2), started_at: DateTime.now
        end
      end

      context 'when user is not subscribed to offline notifications' do
        setup do
          @user.update_attribute(:subscribed_notifications, [])
        end

        should 'not deliver device_offline mail if device belongs to the group' do
          expect_device_offline_mail_deliver(false)
          OfflineEvent.create device: @device, started_at: DateTime.now
        end
      end
    end

    context 'with user not subscribed' do
      setup do
        @user.update_attributes(enotify: User::NOTIFICATIONS[:disable])
      end

      should 'NOT send an email' do
        assert_no_difference('ActionMailer::Base.deliveries.count') do
          OfflineEvent.create device: @device, started_at: DateTime.now
        end
      end
    end
  end

  def expect_device_offline_mail_deliver(expect_notification)
    mail = mock()
    if expect_notification
      mail.expects(:deliver_now)
      Notifier.expects(:device_offline).with(@user, @device).returns(mail).once
    else
      mail.expects(:deliver_now).never
      Notifier.expects(:device_offline).with(@user, @device).returns(mail).never
    end
  end
end
