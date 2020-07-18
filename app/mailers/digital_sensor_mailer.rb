class DigitalSensorMailer < ActionMailer::Base
  def digital_sensor_mail(user, reading)
    @user = user
    @sensor_reading = reading.digital_sensor_reading
    subject = "GoTrack - Digital sensor #{@sensor_reading.digital_sensor_name} has changed for device #{reading.device_name}"
    mail(from: ALERT_EMAIL, to: @user.email, subject: subject)
  end
end
