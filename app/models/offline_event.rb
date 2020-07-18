class OfflineEvent < ActiveRecord::Base

  self.primary_key = :id

  def self.expire_offline_devices
    devices = ::Device.provisioned.where(last_offline_event_at: nil)
    devices = devices.where('last_online_time + interval offline_threshold minute < now()') unless Rails.env.test? # TODO ARG!!! cannot use this qualifier w/ SQLite
    Rails.logger.info "#{Time.now.utc} - CONSIDER OFFLINE EVENTS #{devices.length}"
    devices.each do |device|
      begin
        device.check_offline_event!
      rescue
        Rails.logger.error "#{Time.now.utc} - OFFLINE EVENT ERROR[#{device.id} - #{device.imei}]: #{$!}"
      end
    end
  end

  belongs_to :device
end
