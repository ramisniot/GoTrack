class IdleAlertMailer < ActionMailer::Base
  def idle_extended_alert_mail(user, idle_event)
    @user = user
    @device = idle_event.device
    @idle_event = idle_event
    @reading = idle_event.start_reading

    unless @reading.location
      ReverseGeocoder.find_all_reading_addresses([idle_event.start_reading])
      @reading.reload
    end

    subject = "GoTrack - Device #{@device.name} has exceeded the maximum idle time"
    mail(from: ALERT_EMAIL, to: @user.email, subject: subject)
  end
end
