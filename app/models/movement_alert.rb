class MovementAlert < ActiveRecord::Base
  belongs_to :user
  belongs_to :device
  belongs_to :violating_reading, class_name: 'Reading'

  acts_as_mappable lat_column_name: :latitude, lng_column_name: :longitude

  # You can't create a new movement alert on this device until the old one has triggered.
  validates_uniqueness_of :violating_reading_id, scope: [:device_id, :user_id]

  RADIUS = 0.10 # miles

  scope :open_alerts, -> { where('user_notified IS NULL AND violating_reading_id IS NULL') }
  scope :need_delivering, -> { where('user_notified IS NULL AND violating_reading_id IS NOT NULL') }

  # TODO: Change attribute accessible
  # attr_accessible :user_id, :device_id, :violating_reading_id, :latitude, :longitude

  def self.open_device_ids
    open_alerts.all(select: 'device_id').map(&:device_id).uniq
  end

  def mark_as_closed(reading = nil)
    update_attribute(:violating_reading_id, reading.id) unless reading.nil?
  end

  def deliver_now
    notification = Notifier.movement_alert(self)
    notification.deliver_now
    update_attribute(:user_notified, Time.now)
  end

  def is_violated_by(reading)
    reading && (reading.device_id == device_id) && (reading.distance_to(self) > RADIUS)
  end
end
