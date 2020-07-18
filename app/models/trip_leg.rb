class TripLeg < ActiveRecord::Base
  belongs_to :device
  belongs_to :trip_event
  belongs_to :reading_start, class_name: 'Reading'
  belongs_to :reading_stop, class_name: 'Reading'

  scope :not_suspect, -> { where(suspect: false) }

  def readings
    return @readings unless @readings.blank?
    return [] unless self.reading_start && self.reading_stop && self.trip_event && self.trip_event.device

    @readings = Reading.where("device_id = ? AND recorded_at >= ? AND recorded_at <= ?", self.trip_event.device_id, self.reading_start.recorded_at, self.reading_stop.recorded_at).order('recorded_at')
  end

  alias_method :reading, :reading_start

  def stop_event
    StopEvent.where('device_id = ? AND started_at = ? ', self.trip_event.device_id, self.reading_stop.recorded_at).first
  end

  def latitude
    self.reading.latitude
  end

  def longitude
    self.reading.longitude
  end

  def update_stats!
    return unless reading_start and reading_stop
    self.idle = IdleEvent.where('device_id = ? AND started_at >= ? AND started_at <= ? and (suspect is null or suspect = false) and duration >= 3', self.trip_event.device_id, reading_start.recorded_at, reading_stop.recorded_at).sum(:duration)
    self.distance = 0
    self.max_speed = 0
    last_reading = nil
    readings.reject { |x| x.latitude.to_f.zero? || x.longitude.to_f.zero? }.each do |next_reading|
      self.max_speed = next_reading.speed if next_reading.speed and self.max_speed < next_reading.speed

      next_distance = last_reading.distance_from(next_reading) if last_reading
      if last_reading && next_distance
        self.distance += next_distance.to_f
      end
      last_reading = next_reading
    end
    save!
  end

  def calculate_mileage_and_duration_by_state
    return unless reading_start and reading_stop
    total = {}
    previous_reading = nil
    readings.reject { |x| x.latitude.to_f.zero? || x.longitude.to_f.zero? }.each do |next_reading|
      if previous_reading
        mileage = previous_reading.distance_from(next_reading)
        duration = next_reading.recorded_at - previous_reading.recorded_at

        next_reading.try :force_location
        next_reading.reload if next_reading.location.nil?
        next if next_reading.location.nil?

        state = next_reading.location.state_abbr

        info = { state => { mileage: (mileage || 0).to_f, duration: (duration || 0) } }
        total.merge!(info) { |key, v1, v2| v1.merge(v2) { |key, v1, v2| v1 += v2 } }
      end
      previous_reading = next_reading
    end
    return total
  end

  def stop_duration(next_leg_start)
    if next_leg_start && reading_stop
      (next_leg_start - reading_stop.recorded_at) / 60
    end
  end
end
