require 'test_helper'

class DigitalSensorMailerTest < ActionMailer::TestCase
  def setup
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    now = Time.parse('2015-04-04 12:00:00 UTC')
    Time.stubs(:now).returns(now)
    @device = FactoryGirl.build(:device, name: 'EJR-9127')
    @user = FactoryGirl.build(:user, first_name: 'John', last_name: 'Smith', email: 'test@test.com', time_zone: 'CET')
    @reading = FactoryGirl.build(:reading, device: @device, recorded_at: Time.now)
    @digital_sensor = FactoryGirl.build(:digital_sensor, name: 'Door', high_label: 'Open', low_label: 'Close')
  end

  context 'digital sensor reading with high value' do
    setup do
      DigitalSensorReading.new(digital_sensor: @digital_sensor, reading: @reading, value: true, recorded_at: Time.now, received_at: Time.now)
      @mail = DigitalSensorMailer.digital_sensor_mail(@user, @reading)
    end

    should 'have the correct content' do
      assert_equal [ALERT_EMAIL], @mail.from
      assert_equal [@user.email], @mail.to
      assert_equal "GoTrack - Digital sensor Door has changed for device EJR-9127", @mail.subject
      assert_equal read_fixture('high_digital_sensor_mail.txt').join, @mail.body.to_s
    end
  end

  context 'digital sensor reading with low value' do
    setup do
      DigitalSensorReading.new(digital_sensor: @digital_sensor, reading: @reading, value: false, recorded_at: Time.now, received_at: Time.now)
      @mail = DigitalSensorMailer.digital_sensor_mail(@user, @reading)
    end

    should 'have the correct content' do
      assert_equal [ALERT_EMAIL], @mail.from
      assert_equal [@user.email], @mail.to
      assert_equal "GoTrack - Digital sensor Door has changed for device EJR-9127", @mail.subject
      assert_equal read_fixture('low_digital_sensor_mail.txt').join, @mail.body.to_s
    end
  end
end
