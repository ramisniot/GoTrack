require 'test_helper'

class NotifierTest < ActionMailer::TestCase
  fixtures :readings, :devices, :users, :accounts, :groups, :group_notifications

  test 'device_offline' do
    user = users(:dennis)
    device = devices(:device1)
    device.update_attribute(:last_online_time, DateTime.now - 6.months)

    @expected.from    = ALERT_EMAIL
    @expected.to      = user.email
    @expected.subject = 'Device Offline Notification'
    @expected.body    = read_fixture('device_offline_notification.txt')

    mail = Notifier.device_offline(user, device)
    assert_mail(mail)
  end

  test 'notify_reading' do
    user = users(:dennis)
    reading = readings(:reading1)
    reading.update_attribute(:recorded_at, DateTime.new(2013, 01, 01))

    @expected.from    = ALERT_EMAIL
    @expected.to      = user.email
    @expected.subject = 'device 1 did some action'
    @expected.body    = read_fixture('notify_reading.txt')

    mail = Notifier.notify_reading(user, 'did some action', reading)
    assert_mail(mail)
  end

  context 'send_notify_reading_to_users' do
    setup do
      @reading = readings(:reading1)
      @user = users(:dennis)
      @account = accounts(:dennis)
      @action = 'did something'
      @reading.device.stubs(:account).returns(@account)
    end

    should 'NOT send an email if device is unassigned' do
      @reading.device.stubs(:account).returns(nil)

      assert_no_difference('ActionMailer::Base.deliveries.count') do
        Notifier.send_notify_reading_to_users(@action, @reading, :startup)
      end
    end

    context 'when type is offline' do
      should 'deliver notification if subscribed to offline' do
        @user.update_attribute(:subscribed_notifications, [:offline])
        mail = mock()
        mail.expects(:deliver_now)

        Notifier.expects(:notify_reading).returns(mail)
        Notifier.send(:send_notify_reading_to_users, @action, @reading, :offline)
      end

      should 'not deliver notification if not subscribed to offline' do
        @user.update_attribute(:subscribed_notifications, [])
        mail = mock()
        mail.expects(:deliver_now).never

        Notifier.expects(:notify_reading).returns(mail).never
        Notifier.send(:send_notify_reading_to_users, @action, @reading, :offline)
      end
    end

    context 'when type is idling' do
      should 'deliver notification if subscribed to idling' do
        @user.update_attribute(:subscribed_notifications, [:idling])
        mail = mock()
        mail.expects(:deliver_now)

        Notifier.expects(:notify_reading).returns(mail)
        Notifier.send(:send_notify_reading_to_users, @action, @reading, :idling)
      end

      should 'not deliver notification if not subscribed to idling' do
        @user.update_attribute(:subscribed_notifications, [])
        mail = mock()
        mail.expects(:deliver_now).never

        Notifier.expects(:notify_reading).returns(mail).never
        Notifier.send(:send_notify_reading_to_users, @action, @reading, :idling)
      end
    end

    context 'when type is sensors' do
      should 'deliver notification if subscribed to sensors' do
        @user.update_attribute(:subscribed_notifications, [:sensor])
        mail = mock()
        mail.expects(:deliver_now)

        Notifier.expects(:notify_reading).returns(mail)
        Notifier.send(:send_notify_reading_to_users, @action, @reading, :sensor)
      end

      should 'not deliver notification if not subscribed to sensors' do
        @user.update_attribute(:subscribed_notifications, [])
        mail = mock()
        mail.expects(:deliver_now).never

        Notifier.expects(:notify_reading).returns(mail).never
        Notifier.send(:send_notify_reading_to_users, @action, @reading, :sensor)
      end
    end

    context 'when type is speed' do
      should 'deliver notification if subscribed to speed' do
        @user.update_attribute(:subscribed_notifications, [:speed])
        mail = mock()
        mail.expects(:deliver_now)

        Notifier.expects(:notify_reading).returns(mail)
        Notifier.send(:send_notify_reading_to_users, @action, @reading, :speed)
      end

      should 'not deliver notification if not subscribed to speed' do
        @user.update_attribute(:subscribed_notifications, [])
        mail = mock()
        mail.expects(:deliver_now).never

        Notifier.expects(:notify_reading).returns(mail).never
        Notifier.send(:send_notify_reading_to_users, @action, @reading, :speed)
      end
    end

    context 'when type is geofence' do
      should 'deliver notification if subscribed to geofence' do
        @user.update_attribute(:subscribed_notifications, [:geofence])
        mail = mock()
        mail.expects(:deliver_now)

        Notifier.expects(:notify_reading).returns(mail)
        Notifier.send(:send_notify_reading_to_users, @action, @reading, :geofence)
      end

      should 'not deliver notification if not subscribed to geofence' do
        @user.update_attribute(:subscribed_notifications, [])
        mail = mock()
        mail.expects(:deliver_now).never

        Notifier.expects(:notify_reading).returns(mail).never
        Notifier.send(:send_notify_reading_to_users, @action, @reading, :geofence)
      end
    end

    context 'when type is non_working' do
      should 'deliver notification' do
        @user.update_attribute(:subscribed_notifications, [])
        mail = mock()
        mail.expects(:deliver_now)

        Notifier.expects(:notify_reading).returns(mail)
        Notifier.send(:send_notify_reading_to_users, @action, @reading, :non_working)
      end
    end

    context 'when type is gpio' do
      should 'deliver notification if subcribed to gpio' do
        @user.update_attribute(:subscribed_notifications, [:gpio])
        mail = mock()
        mail.expects(:deliver_now)

        Notifier.expects(:notify_reading).returns(mail)
        Notifier.send(:send_notify_reading_to_users, @action, @reading, :gpio)
      end

      should 'not deliver notification if not subcribed to gpio' do
        @user.update_attribute(:subscribed_notifications, [])
        mail = mock()
        mail.expects(:deliver_now).never

        Notifier.expects(:notify_reading).returns(mail).never
        Notifier.send(:send_notify_reading_to_users, @action, @reading, :gpio)
      end
    end

    context 'when type is first_movement' do
      should 'deliver notification if subscribed to first movement' do
        @user.update_attribute(:subscribed_notifications, [:first_movement])
        mail = mock()
        mail.expects(:deliver_now)

        Notifier.expects(:notify_reading).returns(mail)
        Notifier.send(:send_notify_reading_to_users, @action, @reading, :first_movement)
      end

      should 'not deliver notification if not subscribed to first movement' do
        @user.update_attribute(:subscribed_notifications, [])
        mail = mock()
        mail.expects(:deliver_now).never

        Notifier.expects(:notify_reading).returns(mail).never
        Notifier.send(:send_notify_reading_to_users, @action, @reading, :first_movement)
      end
    end

    context 'when type is startup' do
      should 'deliver notification if subscribed to startup' do
        @user.update_attribute(:subscribed_notifications, [:startup])
        mail = mock()
        mail.expects(:deliver_now)

        Notifier.expects(:notify_reading).returns(mail)
        Notifier.send(:send_notify_reading_to_users, @action, @reading, :startup)
      end

      should 'not deliver notification if not subscribed to startup' do
        @user.update_attribute(:subscribed_notifications, [])
        mail = mock()
        mail.expects(:deliver_now).never

        Notifier.expects(:notify_reading).returns(mail).never
        Notifier.send(:send_notify_reading_to_users, @action, @reading, :startup)
      end
    end

    context 'when type is gps_unit_power' do
      should 'deliver notification if subscribed to gps_unit_power' do
        @user.update_attribute(:subscribed_notifications, [:gps_unit_power])
        mail = mock()
        mail.expects(:deliver_now)

        Notifier.expects(:notify_reading).returns(mail)
        Notifier.send(:send_notify_reading_to_users, @action, @reading, :gps_unit_power)
      end

      should 'not deliver notification if not subscribed to gps_unit_power' do
        @user.update_attribute(:subscribed_notifications, [])
        mail = mock()
        mail.expects(:deliver_now).never

        Notifier.expects(:notify_reading).returns(mail).never
        Notifier.send(:send_notify_reading_to_users, @action, @reading, :gps_unit_power)
      end
    end

    context 'with user subscribed at account level' do
      should 'deliver notify_reading mail' do
        @user.update_attribute(:subscribed_notifications, [:startup])
        expect_notify_reading_mail_deliver(true)
        Notifier.send_notify_reading_to_users(@action, @reading, :startup)
      end

      context 'when user is not subscribed to any notifications' do
        setup do
          @user.update_attribute(:subscribed_notifications, [])
        end

        should 'not deliver notify_reading mail' do
          expect_notify_reading_mail_deliver(false)
          Notifier.send_notify_reading_to_users(@action, @reading, :startup)
        end
      end
    end

    context 'with user subscribed at group level' do
      setup do
        @user.update_attributes(enotify: User::NOTIFICATIONS[:all_in_fleet])
        @user.update_attribute(:subscribed_notifications, [:startup])
      end

      should 'deliver notify_reading mail if device belongs to the group' do
        expect_notify_reading_mail_deliver(true)
        Notifier.send_notify_reading_to_users(@action, @reading, :startup)
      end

      should 'NOT send an email if device does not belongs to the group' do
        @reading.device.update_attributes(group_id: groups(:group5).id)

        assert_no_difference('ActionMailer::Base.deliveries.count') do
          Notifier.send_notify_reading_to_users(@action, @reading, :startup)
        end
      end

      context 'when user is not subscribed to readings notifications' do
        setup do
          @user.update_attribute(:subscribed_notifications, [])
        end

        should 'not deliver notify_reading mail if device belongs to the group' do
          expect_notify_reading_mail_deliver(false)
          Notifier.send_notify_reading_to_users(@action, @reading, :startup)
        end
      end
    end

    context 'with user not subscribed' do
      setup do
        @user.update_attributes(enotify: User::NOTIFICATIONS[:disable])
      end

      should 'NOT send an email' do
        assert_no_difference('ActionMailer::Base.deliveries.count') do
          Notifier.send_notify_reading_to_users(@action, @reading, :startup)
        end
      end
    end
  end

  context 'send_notify_task_to_users' do
    setup do
      account = FactoryGirl.create(:account)
      @user = FactoryGirl.create(:user, account: account)

      @task = Maintenance.new
      @task.device = Device.new(account_id: account.id)

      @logger = mock()
      @action = mock()
    end

    context 'not deliver notification if user is not subscribed' do
      should 'not deliver notification of any kind' do
        @user.update_attribute(:subscribed_notifications, [])

        mail = mock()
        mail.expects(:deliver_now).never
        Notifier.expects(:notify_task).never

        Notifier.send(:send_notify_task_to_users, @action, @task, @looger)
      end
    end

    context 'Maintenance' do
      should 'deliver notification for Maintenance' do
        @user.update_attribute(:subscribed_notifications, [:maintenance])

        mail = mock()
        mail.expects(:deliver_now)
        @logger.expects(:info)
        Notifier.expects(:notify_task).returns(mail)

        Notifier.send(:send_notify_task_to_users, @action, @task, @logger)
      end
    end
  end

  private

  def assert_mail(mail)
    assert_equal @expected.from,      mail.from
    assert_equal @expected.to,        mail.to
    assert_equal @expected.subject,   mail.subject
    assert_equal @expected.body.to_s, mail.body.to_s
    assert_difference('ActionMailer::Base.deliveries.count', +1) do
      mail.deliver_now
    end
  end

  def expect_notify_reading_mail_deliver(expect_notification)
    mail = mock()
    if expect_notification
      mail.expects(:deliver_now)
      Notifier.expects(:notify_reading).with(@user, @action, @reading).returns(mail)
    else
      mail.expects(:deliver_now).never
      Notifier.expects(:notify_reading).with(@user, @action, @reading).returns(mail).never
    end
  end
end
