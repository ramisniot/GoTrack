module DeviceOwner
  extend ActiveSupport::Concern

  included do
  end

  module ClassMethods
  end

  def clear_devices_from_cache
    self.owned_devices.each{|device| device.clear_device_from_cache}
  end
end
