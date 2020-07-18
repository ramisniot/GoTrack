class OfflineEventEmailObserver < ActiveRecord::Observer
  observe :offline_event

  def after_create(offline_event)
    begin
      send_notification(offline_event)
    rescue
      Rails.logger.info "WARNING: EXCEPTION CAPTURED AT OfflineEventEmailObserver for object \n#{offline_event.inspect}\n EXCEPTION:\n #{$!}"
    end
  end

  def send_notification(offline_event)
    device = offline_event.device
    return unless device && device.account

    device.on_subscribed_users(:offline) { |user| Notifier.device_offline(user, device).deliver_now }
  end
end
