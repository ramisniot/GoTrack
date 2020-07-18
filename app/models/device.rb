class Device < ActiveRecord::Base
  include ApplicationHelper

  REPORT_TYPE_ALL       = 0
  REPORT_TYPE_TRIP      = 1
  REPORT_TYPE_STOP      = 2
  REPORT_TYPE_IDLE      = 3
  REPORT_TYPE_SPEEDING  = 4
  REPORT_TYPE_RUNTIME   = 5
  REPORT_TYPE_GPIO1     = 6
  REPORT_TYPE_GPIO2     = 7

  MIN_JITTER_DISTANCE   = 0.25 # miles

  DEFAULT_DEVICE_GATEWAY = 'calamp'.freeze

  STATUS = {
    stopped: 'Stopped',
    moving: 'Moving',
    idle: 'Idle'
  }.freeze

  MAX_LENGTH = {
    name: 75,
    imei: 30,
    phone_number: 20
  }.freeze

  belongs_to :account
  belongs_to :group, inverse_of: :devices
  belongs_to :last_gps_reading, class_name: 'Reading'
  belongs_to :last_rg_reading,  class_name: 'Reading'
  belongs_to :last_reading,     class_name: 'Reading'
  belongs_to :open_trip_event,  class_name: 'TripEvent'
  belongs_to :open_stop_event,  class_name: 'StopEvent'
  belongs_to :open_idle_event,  class_name: 'IdleEvent'
  belongs_to :last_battery_level_reading, class_name: 'Reading'
  belongs_to :last_speed_reading, class_name: 'Reading'
  belongs_to :last_geofence_reading, class_name: 'Reading'

  delegate :latitude, :longitude, :direction, :speed, :short_address, to: :last_gps_reading, allow_nil: true
  delegate :location, to: :last_gps_reading, allow_nil: true

  alias_method :address, :short_address

  belongs_to :last_mileage_reading, class_name: 'Reading'

  has_many :readings, (-> { order('readings.recorded_at desc') })
  has_many :geofences, (-> { order('created_at desc').limit(300) })
  has_many :geofence_violations, -> { where('EXISTS(SELECT * FROM geofences WHERE geofences.id = geofence_id)').order('geofence_id ASC') }, dependent: :destroy
  has_many :movement_alerts, (-> { where('violating_reading_id IS NULL') })
  has_many :offline_events
  has_many :trip_events
  has_many :idle_events
  has_many :stop_events, (-> { order('created_at desc') })
  has_many :trip_legs, -> { order('started_at ASC') }
  has_many :maintenances
  has_many :digital_sensors, dependent: :destroy, autosave: true

  scope :provisioned, (-> { where('provision_status_id = ?', ProvisionStatus::STATUS_ACTIVE) })
  scope :default, (-> { where('group_id IS NULL') })
  scope :by_name, (-> { order('name ASC') })
  scope :not_deleted, (-> { where("#{table_name}.provision_status_id IN (?)", [ProvisionStatus::STATUS_ACTIVE, ProvisionStatus::STATUS_INACTIVE]) })


  delegate :notify_on_working_hours?, to: :account, prefix: false, allow_nil: true

  accepts_nested_attributes_for :digital_sensors

  validates :imei, presence: true # :uniqueness is being validated "manually"
  validates :imei, length: { maximum: MAX_LENGTH[:imei] }
  validates_uniqueness_of :imei, message: 'must be unique; this one is already in use.'

  validates :name, presence: true
  validates :name, length: { maximum: MAX_LENGTH[:name] }

  validates :thing_token, presence: true, if: :validate_think_token_presence?
  validates :thing_token, uniqueness: { allow_nil: true }

  validates :phone_number, length: { maximum: MAX_LENGTH[:phone_number] }

  validates :idle_threshold, numericality: { greater_than_or_equal_to: 0, only_integer: true }, allow_nil: true

  before_save :check_group_account_consistency
  before_save :check_sensors_changes

  after_save :update_default_digital_sensors
  after_save :re_enqueue_open_idle_event, if: :idle_threshold_changed?

  after_update :clear_device_from_cache, if: :event_processing_change?

  attr_accessor :current_user

  def self.per_page
    25
  end

  def event_processing_change?
    (self.changed & %w(name group_id profile_id imei thing_token device_type idle_threshold offline_threshold battery_level_threshold notify_on_gps_unit_power_events)).any?
  end

  def sync_and_create
    @skip_thing_token_validation = true

    return self.errors.full_messages unless self.validate

    if self.account_id
      new_account = Account.find(self.account_id) if self.account_id != 0
      collection_token = new_account ? new_account.collection_token : nil
    end

    self.provision_status_id = new_account ? ProvisionStatus::STATUS_ACTIVE : ProvisionStatus::STATUS_INACTIVE

    device_attrs = prepare_device_attrs(collection_token)
    response = QiotApi.create_thing(device_attrs)

    if response[:success]
      thing_data = response[:data].with_indifferent_access['thing']
      self.thing_token = thing_data['thing_token']

      @skip_thing_token_validation = false
      save
      self.errors
    else
      [response[:error]]
    end
  end

  def sync_and_update(attrs)
    errors = []
    self.assign_attributes(attrs)
    valid = self.validate

    Rails.logger.info "BEFORE[#{self.provision_status_id},#{valid}]: #{attrs.inspect}"
    if valid
      if self.account_id
        new_account = Account.find(self.account_id) if self.account_id != 0
        collection_token = new_account ? new_account.collection_token : nil
      else
        collection_token = self.account.collection_token
      end

      self.provision_status_id = ProvisionStatus::STATUS_INACTIVE unless new_account

      device_attrs = prepare_device_attrs(collection_token)
      response = QiotApi.update_thing(device_attrs, self.thing_token)

      Rails.logger.info "MIDDLE: #{response[:success]},#{response[:error]}"
      if response[:success]
        self.save
      else
        self.restore_attributes
        errors << response[:error] || 'Unknown service error'
      end
    else
      errors = self.errors.full_messages
    end

    Rails.logger.info "AFTER[#{self.provision_status_id}]: #{errors.inspect}"
    errors
  end

  def prepare_device_attrs(collection_token)
    JSON.dump({ label: self.name, identities: [{ type: 'IMEI', value: self.imei }], deleted: false, collection_token: collection_token })
  end

  def delete
    errors = []

    update_attributes = { provision_status_id: ProvisionStatus::STATUS_DELETED }
    update_attributes[:name] = '-' if self.name == '' || self.name.nil?
    update_result = self.update_attributes(update_attributes)
    errors = self.errors if !update_result

    errors
  end

  def clear_history(defer_deletion = true)
    if defer_deletion
      RabbitMessageProducer.publish_clear_device_history(self.thing_token)
    else
      Reading.where(device_id: self.id).delete_all
      Geofence.where(device_id: self.id).delete_all
      GeofenceViolation.where(device_id: self.id).delete_all
      MovementAlert.where(device_id: self.id).delete_all
      OfflineEvent.where(device_id: self.id).delete_all
      TripEvent.where(device_id: self.id).delete_all
      IdleEvent.where(device_id: self.id).delete_all
      StopEvent.where(device_id: self.id).delete_all
      Maintenance.where(device_id: self.id).delete_all
    end

    self.last_gps_reading = nil
    self.last_rg_reading = nil
    self.last_reading = nil
    self.open_trip_event = nil
    self.open_stop_event = nil
    self.open_idle_event = nil
    self.last_battery_level_reading = nil
    self.last_speed_reading = nil
    self.last_geofence_reading = nil
    save!
  end

  def soft_destroy
    self.provision_status_id = ProvisionStatus::STATUS_DELETED
    save!(validate: false)
    @destroyed = true
    freeze
  end

  def active?
    self.provision_status_id == ProvisionStatus::STATUS_ACTIVE
  end

  def deleted?
    self.provision_status_id == ProvisionStatus::STATUS_DELETED
  end

  def inactive?
    self.provision_status_id == ProvisionStatus::STATUS_INACTIVE
  end

  def available_gateways
    GatewayProperties.all
  end

  def gateway_properties
    @gateway_properties ||= GatewayProperties.by_name(gateway_name || DEFAULT_DEVICE_GATEWAY)
  end

  def available_device_types
    gateway_properties.device_types
  end

  def properties
    @properties ||= DeviceTypeProperties.by_name(device_type || gateway_properties.default_device_type)
  end

  def supports_telematics?
    !!properties.supports_telematics
  end

  def supports_ignition?
    !!properties.supports_ignition
  end

  def supports_motion?
    !!properties.supports_motion
  end

  def max_digital_sensors
    properties.max_digital_sensors || 0
  end

  def users_to_notify
    account.try(:users) || []
  end

  def self.search_for_devices(params, page)
    search(params).result.paginate(page: page)
  end

  def clean_error_messages
    # The IMEI message can't be overridden in the validates_uniqueness_of :message param, so, whatever
    self.errors.to_a.map { |s| s.gsub(/^Imei Please.*/, 'This IMEI is already in use') }.uniq
  end

  def distance_to(lat_lon)
    return 1.0 / 0 unless self.last_gps_reading #infinity
    lat, lon = lat_lon.split(/,/).map(&:to_f)
    self.last_gps_reading.distance_to([lat, lon])
  end

  def consider_geofence_reading?(reading)
    return if reading.latitude.blank? or reading.longitude.blank? or self.account_id.nil?
    return if self != reading.device
    return if reading.id == self.last_geofence_reading_id

    result = self.last_geofence_latitude.nil? ||
             self.last_geofence_longitude.nil? ||
             self.last_geofence_speed.to_i != 0 ||
             self.last_ignition_state ||
             reading.speed.to_i != 0 ||
             reading.ignition ||
             reading.distance_to([self.last_geofence_latitude, self.last_geofence_longitude]) > MIN_JITTER_DISTANCE

    if not result and self.last_geofence_reading and self.last_geofence_reading.geofence_id.to_i != 0
      Rails.logger.info "SKIP GEOFENCE READING #{reading.id}"
      reading.update_attributes(geofence_id: self.last_geofence_reading.geofence_id, geofence_event_type: Reading::GEOFENCE_TYPE_NORMAL)
    else
      Rails.logger.info "NOTE GEOFENCE READING #{reading.id}"
      self.last_geofence_reading_id = reading.id
      self.last_geofence_latitude   = reading.latitude
      self.last_geofence_longitude  = reading.longitude
      self.last_geofence_speed      = reading.speed
    end

    result
  end

  def max_speed
    return @max_speed unless @max_speed.nil?
    begin
      @max_speed ||= self.group.nil? || self.group.max_speed.to_i.zero? ? (self.account.nil? ? nil : self.account.max_speed) : self.group.max_speed
    rescue
      #who cares?
    end
    return @max_speed
  end

  def request_location?
    gateway_device and gateway_device.respond_to?('submit_location_request')
  end

  def last_location_request
    gateway_device.last_location_request if request_location?
  end

  def submit_location_request
    gateway_device.submit_location_request if request_location?
  end

  def gateway_device
    return if @gateway_device == :false
    return @gateway_device if @gateway_device
    return unless (gateway = Gateway.find(gateway_name))
    @gateway_device = gateway.device_class.constantize.where(imei: imei).first
    return unless @gateway_device
    @gateway_device.logical_device = self
    @gateway_device
  rescue
    logger.info "ERROR: NO GATEWAY ''#{gateway_name}' FOUND FOR IMEI '#{imei}''"
    @gateway_device = :false
    nil
  end

  def gateway_device=(value)
    @gateway_device = value
  end

  def has_movement_alert_for_user(user)
    return false if user.nil?
    self.current_user = user
    self.has_movement_alert_for_current_user
  end

  def has_movement_alert_for_current_user
    return nil if self.current_user.nil?
    self.movement_alerts.where(user_id: self.current_user.id).exists?
  end

  def last_maintenance_notification(type)
    Notification.where('device_id = ? and notification_type = ?', id, type).order('created_at desc').first
  end

  def dt
    return '' unless last_gps_reading
    standard_date_and_time(last_gps_reading.recorded_at)
  end

  def full_dt
    return '' unless last_gps_reading
    standard_full_datetime(last_gps_reading.recorded_at)
  end

  def geofence
    return nil unless last_gps_reading && last_gps_reading.geofence_id && last_gps_reading.geofence_id.positive?
    last_gps_reading.fence_description
  end

  def helper_standard_location(mobile = false)
    location_addr = (last_gps_reading.location ? last_gps_reading.location.format_address : "<div id='geocode_#{last_gps_reading.id}' class='geocode'>Getting Address...</div>") if last_gps_reading
    if last_gps_reading.nil?
      content = 'GPS Not Available'
    elsif current_user.nil? || current_user.is_read_only?
      content = last_gps_reading.geofence ? last_gps_reading.geofence.name : location_addr
    elsif last_gps_reading.geofence
      if mobile
        content = %(<div class="geocode"> #{last_gps_reading.geofence.name}<br/>#{location_addr} </div>)
      else
        content = %(<div class="geocode"> <a href="/geofences/edit/#{last_gps_reading.geofence.id}" class="link-all1" title="View this location">#{last_gps_reading.geofence.name}</a><br/>#{location_addr} </div>)
      end
    else
      if mobile
        content = %(<div class="geocode"> #{location_addr} </div>)
      else
        content = %(<div class="geocode"> <a href="/geofences/new?geofence[latitude]=#{last_gps_reading.latitude}&geofence[longitude]=#{last_gps_reading.longitude}&geofence[address]=#{last_gps_reading.short_address}&geofence[radius]=0.1" class="geocode" title="Add a new location">#{location_addr}</a> </div>)
      end
    end
    content.html_safe
  end

  def latest_status
    latest = last_gps_reading
    return '-' unless latest

    if !supports_ignition? && supports_motion?
      latest.in_motion ? STATUS[:moving] : STATUS[:stopped]
    else
      if latest.ignition.nil?
        latest.speed.to_f.zero? ? STATUS[:stopped] : STATUS[:moving]
      else
        if latest.ignition
          latest.speed.to_f.zero? ? STATUS[:idle] : STATUS[:moving]
        else
          STATUS[:stopped]
        end
      end
    end
  end

  def latest_status_description
    latest = last_gps_reading
    label = latest_status

    label == 'Moving' ? "#{label} (#{latest.direction_string} at #{latest.speed.to_i}mph)" : label
  end

  def latest_digital_sensor_status
    last_gps_reading.try(:digital_sensor_reading).try(:description)
  end

  def online?
    return false if transient
    return true unless offline_threshold
    return false unless last_online_time
    (Time.now - last_online_time) < (offline_threshold * 60)
  end

  def update_mileage!
    # For some reason, there are device with negative mileage, recalculate if this is the case.
    if total_mileage.negative?
      self.total_mileage = 0
      self.last_mileage_reading_id = nil
    end

    if last_gps_reading && (last_gps_reading.id > last_mileage_reading_id.to_i)
      last_measured_location = last_mileage_reading || last_gps_reading
      Reading.where('device_id = ? AND recorded_at > ? AND latitude IS NOT NULL', id, last_measured_location.nil? ? 1.week.ago : last_measured_location.recorded_at).order('recorded_at ASC').each do |reading|
        unless last_measured_location.nil? || last_measured_location.latitude.blank?
          self.total_mileage += last_measured_location.distance_from(reading).to_f
        end
        last_measured_location = reading
      end
      self.last_mileage_reading = last_measured_location
      save
    end
  end

  def update_mileage_tasks(logger = nil)
    logger&.info("#{Time.now.to_s(:db)}: update_mileage_tasks for #{imei} starting")
    tasks_to_update = maintenances.not_completed.mileage
    logger&.info("Mileage tasks not updated yet: #{tasks_to_update.size}")

    tasks_to_update.each do |task|
      # Only update the mileage if this task is eligible for sending in the first place
      task.remaining_miles if task.notified_at.nil? || task.notified_at < 1.day.ago
    end

    logger&.info("#{Time.now.to_s(:db)}: update_mileage_tasks for #{imei} ending")
  end

  def address
    return '' unless last_gps_reading
    last_gps_reading.short_address
  end

  def export_filename
    if name.blank?
      return id.to_s
    else
      return "#{id}_#{name.tr(' ', '_')}"
    end
  end

  def set_battery_level_from_reading(reading)
    self.last_battery_level_reading = reading if reading.battery_voltage
  end

  def check_sensors_changes
    @sensors_changed = self.digital_sensors.any? { |ds| ds.changed? || ds.new_record? }
    true #NOTE: in order to continue with the transaction
  end

  def update_default_digital_sensors
    return unless self.account
    if @sensors_changed
      self.digital_sensors.each do |sensor|
        sensor_template = SensorTemplate.where(account_id: self.account_id, address: sensor.address).first_or_create
        sensor_template.update_attributes(sensor.attributes.select { |key, _| %i(name low_label high_label notification_type).include?(key.to_sym) })
      end
    end
  end

  def sensors
    (1..max_digital_sensors).map { |address| sensor(address) }
  end

  def sensor(address)
    device_digital_sensor = self.digital_sensors.where(address: address)
    return device_digital_sensor.first unless device_digital_sensor.blank?

    DigitalSensor.build_sensor(address, self.account.try(:template_by_address, address))
  end

  def on_subscribed_users(notification_type)
    subscribed_users = Cache.fetch_account_subcribed_users(self.account_id) do
      User.for_account(self.account_id).with_notifications_enabled.to_a
    end

    subscribed_users.each do |user|
      yield user if user.subscribed_to_notifications?(notification_type) && user.want_notifications_for_device?(self)
    end
  end

  def re_enqueue_open_idle_event
    # TODO revisit stompers
    # TelematicsStomper.note_telematics_change(self)
    # self.open_idle_event.try(:enqueue_job_for_time_exceeded)
  end

  def check_group_account_consistency
    self.group_id = nil if self.group and self.account_id != self.group.account_id
  end

  def validate_think_token_presence?
    ENABLE_QIOT_SYNC && !@skip_thing_token_validation
  end

  def date_of_last_reading
    self.readings.by_recorded_at('desc').first.try(:recorded_at)
  end

  def clear_device_from_cache
    RabbitMessageProducer.publish_forget_device(self.thing_token)
  end
end
