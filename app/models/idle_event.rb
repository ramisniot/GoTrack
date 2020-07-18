class IdleEvent < ActiveRecord::Base
  include EventBehavior

  self.primary_key = :id

  belongs_to :reading
  belongs_to :device

  after_create :enqueue_job_for_time_exceeded

  scope :by_started_at, -> { reorder('started_at ASC') }
  scope :not_suspect, -> { where('suspect is null or suspect = false') }
  scope :between_dates, lambda { |start_dt, end_dt| where(started_at: start_dt..end_dt) }

  delegate :idle_threshold, to: :device, allow_nil: true

  def enqueue_job_for_time_exceeded
    if self.idle_threshold && self.device.idle_threshold.positive?
      IdleTimeExceededNotificationWorker.perform_at(
        started_at + self.device.idle_threshold.seconds,
        self.id
      )
    end
  end

  def exceeded_threshold?
    if in_progress?
      self.started_at + self.idle_threshold.seconds < Time.now
    else
      duration && duration >= idle_threshold
    end
  end

  def notify_time_exceeded
    device.on_subscribed_users(:idling) do |user|
      IdleAlertMailer.idle_extended_alert_mail(user, self).deliver_now
    end
  end

  def in_progress?
    end_reading.nil?
  end
end
