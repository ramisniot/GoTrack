require Rails.root.join('lib', 'devise', 'encryptors', 'numerexsha1')

class User < ActiveRecord::Base
  devise :database_authenticatable, :registerable, :recoverable, :rememberable,
    :trackable, :validatable, :timeoutable

  ROLES_BY_PRIVILEGE = %i(superadmin admin read_write view_only)

  bitmask :roles, as: ROLES_BY_PRIVILEGE, null: false, zero_value: :none
  bitmask :view_overlays, as: %i(geofences placemarks traffic), null: false, zero_value: :none

  scope :superadmins, -> { with_roles(:superadmin) }

  TIMEZONEMAPPING = {
    'Pacific Time (US & Canada)'   => 'America/Los_Angeles',
    'Hawaii'                       => 'Pacific/Honolulu',
    'Alaska'                       => 'America/Juneau',
    'Arizona'                      => 'America/Phoenix',
    'Mountain Time (US & Canada)'  => 'America/Denver',
    'Central Time (US & Canada)'   => 'America/Chicago',
    'Eastern Time (US & Canada)'   => 'America/New_York',
    'Indiana (East)'               => 'America/Indiana/Indianapolis'
  }

  NOTIFICATIONS = { disable: 0, all_in_account: 1, all_in_fleet: 2 }

  MAX_LENGTH = {
    first_name: 30,
    last_name:  30
  }

  has_many :background_reports, -> { order('completed DESC, scheduled_for ASC') }, dependent: :destroy
  has_many :pending_reports, -> { where(completed: 0).order('scheduled_for ASC') }, class_name: 'BackgroundReport', dependent: :destroy
  has_many :movement_alerts, -> { where(violating_reading_id: nil) }

  belongs_to :account

  ENABLED_NOTIFICATIONS = [:non_working]
  bitmask :subscribed_notifications, as: [:offline, :idling, :sensor, :speed, :geofence, :gpio, :first_movement, :startup, :gps_unit_power, :maintenance], zero_value: :none

  scope :by_last_name, -> { order('last_name') }
  scope :for_account, -> (account_id) { where(account_id: account_id) }
  scope :with_notifications_enabled, -> { where(enotify: [NOTIFICATIONS[:all_in_account], NOTIFICATIONS[:all_in_fleet]]) }

  validates_presence_of :first_name, :last_name, :email
  validates_uniqueness_of :email

  validates :email, format: { with: Devise.email_regexp, message: "invalid email" }

  validates :first_name, length: { maximum: MAX_LENGTH[:first_name] }
  validates :last_name, length: { maximum: MAX_LENGTH[:last_name] }
  validates :account, presence: true, if: '!roles?(:superadmin)'

  after_save :trigger_account_subscribed_users_change

  attr_accessor :change_password

  def self.available_subscriptions
    User.values_for_subscribed_notifications - [:startup]
  end

  def notify_all_devices_in_account?
    enotify == NOTIFICATIONS[:all_in_account]
  end

  def notify_all_devices_in_fleet?
    enotify == NOTIFICATIONS[:all_in_fleet]
  end

  def want_notifications_for_device?(device)
    notify_all_devices_in_account? || (notify_all_devices_in_fleet? && group_devices_ids.include?(device.id))
  end

  def subscribed_to_notifications?(notification_type)
    ENABLED_NOTIFICATIONS.include?(notification_type) || subscribed_notifications?(notification_type)
  end

  # set a default locale
  def locale
    :en
  end

  def self.encrypt(password, salt)
    Digest::SHA1.hexdigest("--#{salt}--#{password}--")
  end

  def self.per_page
    25
  end

  def self.search_for_users(params, page)
    by_last_name.search(params).result.paginate(page: page)
  end

  def accessible_account_ids
    return @accessible_account_ids if @accessible_account_ids
    if is_super_admin?
      # Super users can see any account within their dealer(s)
      @accessible_account_ids = Account.all.collect(&:id)
    else
      # Regular users can only see devices and users in their own account.
      @accessible_account_ids = [account_id]
    end
    @accessible_account_ids
  end

  def full_name
    if first_name.blank?
      email
    elsif last_name.blank?
      first_name
    else
      [first_name,last_name].join(' ')
    end
  end

  # A user can only grant people permissions up to their own level
  def assignable_roles
    return [:admin, :read_write, :view_only] if roles?(:superadmin)
    return [:admin, :read_write, :view_only] if roles?(:admin)
    return [:read_write, :view_only] if roles?(:read_write)
    []
  end

  def role
    roles.first || :view_only
  end

  def is_read_only?
    role == :view_only
  end

  def is_super_admin?
    roles?(:superadmin)
  end

  def is_admin?
    roles?(:admin) || roles?(:superadmin)
  end

  def group_devices_ids
    gids = GroupNotification.where(user_id: id).map(&:group_id)
    Device.where('group_id in (?)', gids).map(&:id)
  end

  def time_zone
    account ? account.time_zone : 'Central Time (US & Canada)'
  end

  def time_zone=(tz)
    account.update_attribute(:time_zone, tz) unless account.nil?
  end

  def get_time_zone
    TIMEZONEMAPPING["#{account.time_zone}"]
  end

  private

  def trigger_account_subscribed_users_change
    if enotify_changed? || subscribed_notifications_changed?
      Cache.clear_account_subcribed_users(self.account_id)
    end
  end
end
