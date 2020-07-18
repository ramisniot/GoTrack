class Notifier < ActionMailer::Base
  default from: ALERT_EMAIL

  def self.send_maintenance_notifications(logger)
    logger.info("Begin maintenance notifications: #{Time.now}")
    tasks_to_notify = Maintenance.not_completed.with_an_active_device.order(:device_id)
    logger.info("Tasks not completed yet: #{tasks_to_notify.size}")
    tasks_to_notify.each do |task|
      # notified_at stores the date of the last email
      # this will prevent notifications of the same type to occur more than once a day.
      # there's also some logic involving Maintenance.alerted_at, that currently prevents an alert to occur
      # more than once for the same task.
      if (task.notified_at.nil? || task.notified_at < 1.day.ago)
        action = task.alert_status
        send_notify_task_to_users(action, task, logger) if action
        task.save # possibly changed by task.alert_status
      else
        logger.info("#{task.description_task} already notified at #{task.notified_at}")
      end
    end
    logger.info("End maintenance notifications: #{Time.now}")
  end

  def self.send_notify_task_to_users(action, task, logger = nil)
    return nil unless task && task.device && task.device.account && task.device.account.users.any?

    task.device.on_subscribed_users(:maintenance) do |user|
      start_time = Time.now
      mail = notify_task(user, action, task).deliver_now
      logger.info("notifying: #{user.email} about: #{action}... took #{(Time.now - start_time).round(3)}s")
      task.notified_at = DateTime.now
    end
  end

  def self.send_notify_reading_to_users(action, reading, type, logger = Rails.logger)
    unless reading.device.nil? or reading.device.account.nil?
      reading.device.on_subscribed_users(type) do |user|
        begin
          t1 = Time.now
          notify_reading(user, action, reading).deliver_now
          logger.info("notifying: #{user.email} about: #{action}... took #{(Time.now - t1).round(3)}s")
        rescue
          logger.info "ERROR: #{$!}" if logger
          $!.backtrace.each { |line| logger.info line } if logger
        end
      end
    end
  end

  def movement_alert(alert)
    @alert = alert
    timezone = @alert.user.time_zone || 'Central Time (US & Canada)'
    setup_email(@alert.user)
    @subject = "EZ-Alert Instant next movement notification"
    @from = ALERT_EMAIL
    @display_time = (@alert.violating_reading.try(:recorded_at) || DateTime.now).in_time_zone(timezone).strftime(EMAIL_TIMESTAMP_FORMAT)
    mail(to: @recipients, from: @from, subject: @subject)
  end

  def forgot_password(user, url = nil)
    setup_email(user)

    @subject = "Forgotten Password Notification"

    # Email body substitutions
    @name = "#{user.first_name} #{user.last_name}"
    @login = user.email
    @url = url
    @app_name = "GoTrack"
    mail(to: @recipients, from: @from, subject: @subject)
  end

  def change_password(user, password, url = nil)
    setup_email(user)

    # Email header info
    @subject = "Changed Password Notification"

    # Email body substitutions
    @name = "#{user.first_name} #{user.last_name}"
    @login = user.email
    @password = password
    @url = url
    @app_name = "GoTrack"
    mail(to: @recipients, from: @from, subject: @subject)
  end

  def notify_reading(user, action, reading)
    return nil if user.nil?
    @action = action
    @name = "#{user.first_name} #{user.last_name}"
    @device_name = reading.device.name
    timezone = user.time_zone || 'Central Time (US & Canada)'
    @display_time = reading.recorded_at.in_time_zone(timezone).strftime(EMAIL_TIMESTAMP_FORMAT)

    mail(to: user.email, from: ALERT_EMAIL, subject: "#{reading.device.name} #{action}")
  end

  def notify_task(user, action, task)
    @action = action
    @name = "#{user.first_name} #{user.last_name}"
    @device_name = task.device.name
    @task_id = task.id
    if !user.nil? && user.time_zone
      timezone = user.time_zone
    else
      timezone = 'Central Time (US & Canada)'
    end
    @display_time = task.alerted_at.in_time_zone(timezone).inspect

    mail(to: user.email, from: ALERT_EMAIL, subject: task.device.name + ' ' + action)
  end

  def device_offline(user, device)
    @device_name = device.name
    @last_online = device.last_online_time
    @name = "#{user.first_name} #{user.last_name}"

    mail(to: user.email, from: ALERT_EMAIL, subject: 'Device Offline Notification')
  end

  def scheduled_report(scheduled_report)
    user = scheduled_report.user

    if !user.nil? && user.time_zone
      timezone = user.time_zone
    else
      timezone = 'Central Time (US & Canada)'
    end

    email_subj = "#{scheduled_report.report_name} for #{scheduled_report.scheduled_for.in_time_zone(timezone).strftime STANDARD_DATE_FORMAT}"
    email_body = "The report #{scheduled_report.report_name} for #{scheduled_report.scheduled_for.in_time_zone(timezone).strftime STANDARD_DATE_FORMAT} is attached"

    attachments[scheduled_report.filename] = { mime_type: 'text/csv', content: scheduled_report.report_data }
    mail(to: user.email, from: ALERT_EMAIL, subject: email_subj) do |format|
      format.text { render text: email_body }
    end
  end

  # Send email to support from contact page
  def app_feedback(user_email, contact_email, subdomain, feedback)
    @feedback = feedback
    @sender = user_email

    mail(to: SUPPORT_EMAIL, cc: contact_email, from: SUPPORT_EMAIL, subject: "Feedback from #{user_email} at #{subdomain}")
  end

  private

  def setup_email(user)
    @recipients = user.email
    @from       = SUPPORT_EMAIL
    @sent_on    = Time.now
    headers['Content-Type'] = 'text/plain; charset=utf-16'
  end
end
