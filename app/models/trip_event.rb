class TripEvent < ActiveRecord::Base
  include EventBehavior

  self.primary_key = :id

  belongs_to :device
  has_many :trip_legs
  has_many :readings, -> { order('readings.recorded_at, readings.id') }, class_name: 'Reading', through: :device

  scope :not_null, -> (attribute) { where(arel_table[attribute].not_eq(nil)) }
  scope :is_null, -> (attribute) { where(arel_table[attribute].eq(nil)) }
  scope :not_suspect, -> { where(suspect: false) }

  # TODO: Change attribute accessible
  # attr_accessible :started_at, :device_id, :start_reading_id, :end_reading_id, :duration, :ended_at, :suspect, :has_gps,
  #                :speeds_quantity, :speeds_sum, :start_latitude, :start_longitude, :end_latitude, :end_longitude, :speed,
  #                :start_location_id, :end_location_id, :average_speed, :max_speed, :idle_events_quantity, :idle_duration

  after_save :update_info, if: :end_reading_id_changed?
  after_save :sync_leg_suspect_status, if: :suspect_changed?

  def intermediate_readings
    if (!self.start_reading)
      return []
    end
    device.readings.for_date_strict_range(self.started_at, self.ended_at || Time.now.in_time_zone).with_gps.reorder('recorded_at ASC, id ASC')
  end

  def get_first_reading_with_gps
    return self.start_reading unless self.start_reading.latitude.blank? || self.start_reading.longitude.blank?
    r = intermediate_readings.first
    return r unless r.blank?
    self.end_reading unless self.end_reading.blank? || self.end_reading.latitude.blank? || self.end_reading.longitude.blank?
  end

  def close_with(reading)
    self.end_reading = reading
    self.end_latitude = reading.latitude
    self.end_longitude = reading.longitude
    self.end_location = reading.location
    duration = reading.recorded_at - self.start_reading.recorded_at
    self.duration = duration > 0 ? duration : 0 # storing duration in seconds

    self.distance = 0
    previous_r = self.start_reading
    self.intermediate_readings.each do |r|
      self.distance +=  Reading.distance_between_two_lat_lng(previous_r.latitude, previous_r.longitude, r.latitude, r.longitude)
      previous_r = r
    end
    self.distance += Reading.distance_between_two_lat_lng(previous_r.latitude, previous_r.longitude, reading.latitude, reading.longitude)

    self.average_speed = get_average_speed
    self.max_speed = get_max_speed
    self.idle_duration = get_idle_duration
    self.idle_events_quantity = idle_events.size
  end

  # Returns the idle events contained in the trip, if the trip is not closed yet it consider 'Time.now' timestamp
  # for bringing the idle events
  def idle_events
    if device
      device.idle_events.where('started_at >= ? AND ended_at <= ?', self.started_at, self.ended_at || Time.zone.now)
    else
      []
    end
  end

  # Returns the time (in minutes) that the trip was idling
  def get_idle_duration
    duration = 0
    idle_events.each do |i_e|
      duration += i_e.duration unless i_e.duration.blank?
    end
    duration
  end

  # Returns the max speed (mph) of the trip
  def get_max_speed
    all_readings.collect(&:speed).compact.max
  end

  # Returns the average speed (mph) of the trip, it skips nil speeds
  def get_average_speed
    speeds = all_readings.collect(&:speed).compact
    sum_speed = speeds.inject(:+)
    speeds.size > 0 ? sum_speed / speeds.size : nil
  end

  # Returns all the readings that are included in the trip
  def all_readings
    ret = []
    ret << self.start_reading unless self.start_reading.blank?
    ret += intermediate_readings
    ret << self.end_reading unless self.end_reading.blank?
    ret
  end

  def end_reading_with_gps
    unless self.end_reading.blank? || (self.end_reading.latitude.blank? && self.end_reading.longitude.blank?)
      self.end_reading
    else
      intermediate_readings.last
    end
  end

  def suspect?
    s = self.start_reading
    e = self.end_reading
    s_has_gps = !(s.nil? || s.latitude.nil? || s.longitude.nil?)
    e_has_gps = !(e.nil? || e.latitude.nil? || e.longitude.nil?)
    i_rs = self.intermediate_readings

    self.suspect = (!s_has_gps && !e_has_gps) && i_rs.blank?
  end

  def legs
    return [] if readings.empty?

    remaining_readings = readings.by_recorded_at('asc').between_dates(start_reading.recorded_at, end_reading.recorded_at).to_a
    last_leg_end_reading_id = trip_legs.last.reading_stop_id unless trip_legs.empty?
    last_leg_end_reading_id = trip_legs[-2].reading_stop_id if last_leg_end_reading_id.nil? && trip_legs[-2] && trip_legs[-2].reading_stop_id

    unless last_leg_end_reading_id.blank?
      remaining_readings.delete_if { |reading| reading.id <= last_leg_end_reading_id }
    end

    warming_up = true
    until remaining_readings.blank?
      while !warming_up && !remaining_readings.first.blank? && remaining_readings.first.speed == 0
        remaining_readings.shift
      end

      warming_up = false
      return if remaining_readings.blank?

      start = remaining_readings.first
      leg = TripLeg.new(device_id: device_id, trip_event_id: id, reading_start_id: start.id, started_at: start.recorded_at,suspect: false)
      conditions = [
        'device_id = ? AND started_at > ? AND started_at <= ? AND (suspect is NULL or suspect = false)',
        device.id,
        start.recorded_at,
        remaining_readings.last.recorded_at
      ]
      stop = StopEvent.where(conditions).order(:id).first

      if stop && remaining_readings.count { |r| r.recorded_at >= stop.started_at && r.speed && r.speed > 0 } > 0
        leg.reading_stop_id = stop.reading.id
        leg.stopped_at      = stop.reading.recorded_at
      else
        leg.reading_stop_id = remaining_readings.last.id
        leg.stopped_at      = remaining_readings.last.recorded_at
      end

      while remaining_readings.first && remaining_readings.first.id != leg.reading_stop_id
        remaining_readings.shift
      end

      if remaining_readings.first
        leg.duration = (leg.stopped_at - start.recorded_at).round / 60
        leg.save!
        leg.update_stats!
        remaining_readings.shift
        @trip_legs = TripLeg.where(trip_event_id: id)
      else
        return trip_legs
      end
    end
    @trip_legs
  end

  def update_stats!
    return unless start_reading && end_reading && device
    idle_duration = device.idle_events.not_suspect.between_dates(start_reading.recorded_at, end_reading.recorded_at).where('duration >= 180').sum(:duration) / 60
    distance = 0
    last_reading = nil
    readings = device.readings.where('recorded_at between ? and ? and latitude != 0 and longitude != 0', start_reading.recorded_at, end_reading.recorded_at).order('recorded_at')
    readings.each do |next_reading|
      next_distance = last_reading.distance_from(next_reading) if last_reading
      distance += next_distance.to_f if last_reading && next_distance
      last_reading = next_reading
    end
    update_column :idle_duration, idle_duration
    update_column :distance, distance
  end

  private

  def update_info
    return unless end_reading
    update_stats!
    legs
  end

  def sync_leg_suspect_status
    trip_legs.update_all(suspect: self.suspect)
  end
end
