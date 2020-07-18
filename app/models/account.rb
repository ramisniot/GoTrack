class Account < ActiveRecord::Base
  include DeviceOwner

  has_many :devices, -> { order('name') }
  has_many :groups, -> { order('name') }
  has_many :users
  has_many :provisioned_devices, -> { where('devices.provision_status_id = ?', ProvisionStatus::STATUS_ACTIVE).order('name') }, class_name: 'Device'
  has_many :sensor_templates

  serialize :working_hours

  alias_attribute :owned_devices, :devices

  scope :active, -> { where(provision_status_id: ::ProvisionStatus::STATUS_ACTIVE) }
  scope :by_company, -> { order('company collate "C"') }
  scope :by_subdomain, -> { order('subdomain collate "C"') }

  default_scope { active }

  validates :company, presence: true
  validates :subdomain, presence: true

  validates :contact_email, format: { with: Devise.email_regexp, message: "invalid email", allow_blank: true }

  validates :default_map_latitude, numericality: {
    greater_than_or_equal_to: -90, less_than_or_equal_to: 90, allow_nil: true
  }
  validates :default_map_longitude, numericality: {
    greater_than_or_equal_to: -180, less_than_or_equal_to: 180, allow_nil: true
  }

  after_update :clear_devices_from_cache

  def self.per_page
    25
  end

  def soft_destroy
    update_attribute(:provision_status_id, ::ProvisionStatus::STATUS_DELETED)

    selectable_users.clear
    save

    @destroyed = true
    freeze
  end

  def outside_working_hours?(time)
    timezone = (time_zone.presence || 'Central Time (US & Canada)')

    tztime = time.in_time_zone(timezone)

    hour_minute = tztime.strftime('%H%M') # extract hour_minute
    working_hours[tztime.wday].blank? ||
      working_hours[tztime.wday + 7].blank? ||
      hour_minute < working_hours[tztime.wday] ||
      hour_minute > working_hours[tztime.wday + 7]
  end

  def template_by_address(address)
    self.sensor_templates.where(address: address).first
  end

  def devices_with_sensor_support
    provisioned_devices.to_a.select { |device| device.max_digital_sensors && device.max_digital_sensors.positive? }
  end

  def sync_and_save(name)
    errors = []
    valid = self.validate

    if valid
      attrs = JSON.dump({ name: name })
      response = QiotApi.create_collection(attrs)

      if response[:success]
        collection_data = response[:data].with_indifferent_access['collection']
        self.collection_token = collection_data['collection_token']
        !self.save
      else
        self.destroy
        errors << response[:error]
      end
    else
      self.destroy
      errors = self.errors.full_messages
    end
    errors
  end

  def sync_and_update(attrs)
    errors = []
    self.assign_attributes(attrs)
    valid = self.validate

    if valid
      account_attrs = JSON.dump({ name: attrs[:company] })
      response = QiotApi.update_collection(account_attrs, self.collection_token)

      if response[:success]
        !self.save
      else
        self.restore_attributes
        errors << response[:error]
      end
    else
      errors << self.errors.full_messages
    end

    errors
  end

  def sync_and_delete
    response = QiotApi.delete_collection(self.collection_token)
    errors = []

    if response[:success]
      errors = self.errors.full_messages if !self.update_attribute(:provision_status_id, ProvisionStatus::STATUS_DELETED)
    else
      errors << response[:error]
    end
    errors
  end

  def default_map_center
    if default_map_latitude && default_map_longitude
      { lat: self.default_map_latitude, lng: default_map_longitude }
    end
  end
end
