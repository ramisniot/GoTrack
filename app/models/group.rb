class Group < ActiveRecord::Base
  include ApplicationHelper
  include DeviceOwner

  has_many :group_notifications
  has_many :geofences

  belongs_to :account
  has_many :devices, -> { where('devices.provision_status_id = ?', ProvisionStatus::STATUS_ACTIVE).order('name') }, dependent: :nullify, inverse_of: :group
  has_many :owned_devices, class_name: 'Device'

  scope :by_name, -> { order('groups.name ASC') }
  scope :for_user, lambda { |user| where('account_id IN (?)', user.accounts_ids).order('groups.name').includes(:devices) }

  validates_presence_of :name, :account_id, :image_value

  before_save :check_group_account_consistency

  after_update :clear_devices_from_cache, if: :max_speed_changed?

  def is_selected_for_notification(user)
    !GroupNotification.where('user_id = ? and group_id = ?', user.id, id).first.nil?
  end

  def get_readings_from_devices_for_rg
    Reading.where(id: devices.collect(&:last_gps_reading_id), location_id: nil)
  end

  def check_group_account_consistency
    self.devices.each do |device|
      if device.account_id != self.account_id
        device.update_attribute(:group_id, nil)
      end
    end
  end
end
