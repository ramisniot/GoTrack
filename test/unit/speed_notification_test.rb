require File.dirname(__FILE__) + '/../test_helper'

class SpeedNotificationTest < ActiveSupport::TestCase
  def record_notification(action, reading)
    @notified_actions.push(action)
  end

  context "A speed notification" do
    context "with profile that includes speed" do
      setup do
        account = FactoryGirl.create(:account, max_speed: 100)
        @device = FactoryGirl.create(:device, account: account)
      end

      should "not notify on non speeding event" do
        reading = FactoryGirl.create(:reading, device: @device, speed: 99)
        Notifier.expects(:send_notify_reading_to_users).never
        reading.speed_notifications
      end

      should "notify on speeding event" do
        reading = FactoryGirl.create(:reading, device: @device, speed: 170)
        Notifier.expects(:send_notify_reading_to_users).with("maximum speed of #{@device.max_speed} MPH exceeded", reading, :speed).once
        reading.speed_notifications
      end

      should "notify again only after a 0 speed" do
        Notifier.expects(:send_notify_reading_to_users).twice
        reading_1 = FactoryGirl.create(:reading, device: @device, speed: 170)
        reading_1.speed_notifications
        reading_2 = FactoryGirl.create(:reading, device: @device, speed: 170)
        reading_2.speed_notifications
        reading_3 = FactoryGirl.create(:reading, device: @device, speed: 0)
        reading_3.speed_notifications
        reading_4 = FactoryGirl.create(:reading, device: @device, speed: 165)
        reading_4.speed_notifications
      end
    end
  end
end
