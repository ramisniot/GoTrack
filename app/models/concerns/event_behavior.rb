module EventBehavior
  extend ActiveSupport::Concern
  include Geokit::ActsAsMappable

  STATES = {
    open:    0,
    working: 1,
    cleared: 2
  }

  included do
    belongs_to :device
    belongs_to :start_reading,  class_name: 'Reading'
    belongs_to :end_reading,    class_name: 'Reading'
    belongs_to :start_location, class_name: 'Location'
    belongs_to :end_location,   class_name: 'Location'
    belongs_to :working_user,   class_name: 'User'

    acts_as_mappable lat_column_name: :latitude, lng_column_name: :longitude

    scope :for_date_range, lambda { |start_date,end_date| { conditions: ["#{table_name}.started_at  >= ? and #{table_name}.started_at <= ?", start_date, end_date] } }
    scope :after_date , lambda { |date| { conditions: ["#{table_name}.started_at  >= ? ", date] } }
    scope :for_device, lambda { |device_id| { conditions: { device_id: device_id } } }
    scope :with_state, lambda { |state| { conditions: { state: state } } }
    scope :active, lambda { { conditions: ["NOT #{table_name}.state = ?", STATES[:cleared]] } }
    scope :opened, lambda { { conditions: { state: STATES[:open] } } }
  end

  def location
    start_location
  end

  def latitude
    start_reading.try(:latitude)
  end

  def longitude
    start_reading.try(:longitude)
  end

  def event_type_str
    self.start_reading.event_type_str
  end

  def update_location_from_readings
    self.start_location = start_reading.location
    self.end_location = end_reading.location if end_reading
  end

  def close_with reading
    self.end_reading = reading
    self.end_latitude = reading.latitude
    self.end_longitude = reading.longitude
    self.end_location = reading.location
    duration = reading.recorded_at - self.start_reading.recorded_at
    self.duration = duration > 0 ? duration : 0 #storing duration in seconds
  end

  def open?
    end_reading_id.nil?
  end

  def reading
    self.start_reading
  end

end
