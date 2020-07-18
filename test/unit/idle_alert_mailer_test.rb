require 'test_helper'

class IdleAlertMailerTest < ActionMailer::TestCase
  def setup
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    now = Time.parse('2015-04-04 12:00:00 UTC')
    Time.stubs(:now).returns(now)
    @device = FactoryGirl.build(:device, name: 'EJR-9127', idle_threshold: 300)
    @user = FactoryGirl.build(:user, first_name: 'John', last_name: 'Smith', email: 'test@test.com', time_zone: 'CET')
    reading = FactoryGirl.build(:reading, device: @device, location: FactoryGirl.build(:location))
    @idle_event = FactoryGirl.build(:idle_event, device: @device, start_reading: reading, started_at: Time.now)
  end

  context 'Idle alert mailer' do
    setup do
      @mail = IdleAlertMailer.idle_extended_alert_mail(@user, @idle_event)
    end

    should 'have the correct content' do
      assert_equal [ALERT_EMAIL], @mail.from
      assert_equal [@user.email], @mail.to
      assert_equal "GoTrack - Device #{@device.name} has exceeded the maximum idle time", @mail.subject
      assert_equal read_fixture('idle_event_alert.txt').join, @mail.body.to_s
    end
  end
end
