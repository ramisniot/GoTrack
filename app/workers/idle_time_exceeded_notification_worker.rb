class IdleTimeExceededNotificationWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'idle_event_time_exceeded_notification', retry: 1

  sidekiq_retries_exhausted do |message|
    idle_event = IdleEvent.find_by(id: message['args'].first)
    log = "Idle Time Exceed notification job failed for #{idle_event.device.name} imei: #{idle_event.device.imei}" if idle_event&.device
    Rails.logger.info(log || "Idle Time Exceed notification job failed for idle event #{idle_event_id}")
  end

  def perform(idle_event_id)
    idle_event = IdleEvent.find_by(id: idle_event_id)

    idle_event.notify_time_exceeded if idle_event&.exceeded_threshold?
    log = "Idle Time Exceed notification job was successful for #{idle_event.device.name} imei: #{idle_event.device.imei}." if idle_event&.device
    Rails.logger.info(log || "Idle Time Exceed notification job processed for idle event #{idle_event_id}")
  end
end
