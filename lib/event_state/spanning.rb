module EventState
  # Handle Idle, Stop and Trip events creation and expiration
  # also keep up to date the structures that cache the information about those kind of events
  module Spanning
    MIN_STOP_IDLE_SECONDS = 3 * 60      # 3 minutes
    MAX_EXPIRED_SECONDS   = 60 * 60 * 3 # 3 hours

    attr_reader :open_trip_key

    def self.included(base)
      @@open_trip_heap = nil

      base.extend(ClassMethods)
    end

    module ClassMethods
      def ensure_caching_for_open_trips
         ::Device.where('open_trip_event_id is not null').each{|device| for_device(device){|state| state.update_open_trip_heap_status } }
      end

      def end_expired_open_trips
        return unless open_trip_heap

        while (state = open_trip_heap.next) do
          break if state.device.open_trip_event and Time.zone.now - state.device.last_reading.recorded_at < MAX_EXPIRED_SECONDS

          state.end_open_trip

          raise 'state should have been removed from the open trip heap' if open_trip_heap.next == state
        end
      end

      def open_trip_count
        open_trip_heap ? open_trip_heap.size : 0
      end

      def open_trip_heap
        @@open_trip_heap ||= Containers::Heap.new
      end

      def open_trip_heap=(heap)
        @@open_trip_heap = heap
      end
    end

    def consider_transition
      return if @previous_reading == @device.last_reading

      end_open_trip(@previous_reading) if @device.open_trip_event and (@previous_reading.nil? or (@device.last_reading.recorded_at - @previous_reading.recorded_at >= MAX_EXPIRED_SECONDS))

      if @device.last_reading.ignition.nil?
        # NOTE: do nothing -- may be a Heartbeat or other event that does NOT report ignition
      elsif @device.open_trip_event.nil?
        if @device.last_reading.ignition
          begin_new_trip
        elsif @device.open_stop_event.nil?
          ensure_open_stop
        end
      elsif not @device.last_reading.ignition
        end_open_trip
      else
        @device.last_reading.speed > 0 ? end_open_stop_and_idle(@device.last_reading) : ensure_open_stop_and_idle if @device.last_reading.speed
        update_trip_calculated_attributes
        check_for_idling
      end

      @previous_reading = @device.last_reading
      update_open_trip_heap_status
    end

    def ensure_open_stop_and_idle
      ensure_open_stop
      ensure_open_idle
    end

    def ensure_open_idle
      @device.open_idle_event ||= IdleEvent.create!(start_event_attributes)
    end

    def ensure_open_stop
      @device.open_stop_event ||= StopEvent.create!(start_event_attributes)
    end

    def begin_new_trip
      end_open_trip(true) if @device.open_trip_event

      @device.open_trip_event = TripEvent.create!(start_trip_event_attributes)
      @device.last_reading.set_event_type(EventTypes::EngineOn,true)

      if @device.last_reading.speed == 0
        ensure_open_stop_and_idle
      elsif @device.last_reading.speed and @device.last_reading.speed > 0
        end_open_stop(@device.last_reading)
      end
    end

    def end_open_trip(use_previous = false)
      if @device.open_trip_event.nil?
        end_open_idle(nil)
      else
        if use_previous
          closing_reading = @previous_reading
        else
          closing_reading = @device.last_reading
          update_trip_distance(false)
        end

        duration  = calculate_duration(@device.open_trip_event,closing_reading)
        suspect   = @device.open_trip_event.suspect? || duration.nil? || duration <= 0
        end_open_idle(closing_reading)
        @device.open_trip_event.update_attributes!(end_event_attributes(closing_reading, duration, suspect))
        @device.open_trip_event = nil

        if not closing_reading.ignition.nil? and not closing_reading.ignition
          closing_reading.set_event_type(EventTypes::EngineOff,true)
          ensure_open_stop
        end
      end

      update_open_trip_heap_status
    end

    def end_open_stop_and_idle(closing_reading)
      end_open_stop(closing_reading)
      end_open_idle(closing_reading)
    end

    def end_open_idle(closing_reading)
      return unless @device.open_idle_event

      end_open_event(@device.open_idle_event,closing_reading)
      @device.open_idle_event.suspect = true unless @device.open_trip_event
      check_for_idling
      @device.open_trip_event.update_attributes!(
          idle_duration: (@device.open_trip_event.idle_duration || 0) + @device.open_idle_event.duration,
          idle_events_quantity: (@device.open_trip_event.idle_events_quantity || 0) + 1) unless @device.open_idle_event.suspect
      @device.open_idle_event = nil
    end

    def end_open_stop(closing_reading)
      if @device.open_stop_event
        end_open_event(@device.open_stop_event,closing_reading)
        @device.open_stop_event = nil
      end
    end

    def end_open_event(open_event,closing_reading)
      duration = calculate_duration(open_event,closing_reading)
      suspect = duration.nil? || duration < MIN_STOP_IDLE_SECONDS
      open_event.update_attributes!(end_event_attributes(closing_reading,duration,suspect))
    end

    def check_for_idling
      @device.open_idle_event.start_reading.set_event_type(EventTypes::Idling,true) if @device.open_trip_event and @device.open_idle_event and not @device.open_idle_event.suspect and (duration = calculate_duration(@device.open_idle_event,@device.last_reading)) and duration >= MIN_STOP_IDLE_SECONDS
    end

    def calculate_duration(open_event,closing_reading)
      (closing_reading.recorded_at - open_event.started_at).round if closing_reading
    end

    def start_event_attributes
      {
          start_reading_id: @device.last_reading.id,
          start_latitude: @device.last_reading.latitude,
          start_longitude: @device.last_reading.longitude,
          started_at: @device.last_reading.recorded_at,
          device_id: @device.id
      }
    end

    def start_trip_event_attributes
      attrs = start_event_attributes
      attrs.merge!(suspect: !@device.last_reading.has_gps?, has_gps: @device.last_reading.has_gps?)
      attrs.merge!(speeds_quantity: 1, speeds_sum: @device.last_reading.speed) if @device.last_reading.speed
      attrs
    end

    def end_event_attributes(closing_reading,duration,suspect)
      closing_reading ||= ::Reading.new
      {
          end_reading_id: closing_reading.id,
          end_latitude: closing_reading.latitude,
          end_longitude: closing_reading.longitude,
          ended_at: closing_reading.recorded_at,
          duration: duration,
          suspect: suspect
      }
    end

    def update_open_trip_heap_status
      next_heap_key = generate_open_trip_heap_key
      if @open_trip_key.nil?
        self.class.open_trip_heap.push(@open_trip_key = next_heap_key,self) if next_heap_key
      elsif @open_trip_key != next_heap_key
        self.class.open_trip_heap.delete(@open_trip_key)
        self.class.open_trip_heap.push(next_heap_key,self) if next_heap_key
        @open_trip_key = next_heap_key
      end
      Rails.logger.info "#{Time.zone.now.to_s(:db)} - #{$$} - open_trip_heap count: #{self.class.open_trip_count}"
    end

    def generate_open_trip_heap_key
      "#{@device.open_trip_event.started_at.to_s(:db)}$#{@device.id}" if @device.open_trip_event
    end

    def update_trip_calculated_attributes(save_bang = true)
      return unless @device.open_trip_event and @previous_reading != @device.last_reading
      update_trip_distance(false)
      update_trip_max_speed(false)
      update_trip_avg_speed(false)
      update_trip_suspect(false)
      @device.open_trip_event.save! if save_bang
    end

    # PRE: @device.open_trip_event and @previous_reading != @device.last_reading
    def update_trip_distance(save_bang = true)
      @device.open_trip_event.distance = (@device.open_trip_event.distance || 0) + Reading.distance_between_readings(@previous_reading,@device.last_reading)
      @device.open_trip_event.save! if save_bang
    end

    # PRE: @device.open_trip_event and @previous_reading != @device.last_reading
    def update_trip_max_speed(save_bang = true)
      return if @device.last_reading.speed.nil?
      @device.open_trip_event.max_speed = [@device.open_trip_event.max_speed || 0, @device.last_reading.speed].max
      @device.open_trip_event.save! if save_bang
    end

    # PRE: @device.open_trip_event and @previous_reading != @device.last_reading
    def update_trip_avg_speed(save_bang = true)
      return if @device.last_reading.speed.nil?
      open_trip = @device.open_trip_event
      open_trip.speeds_sum = (open_trip.speeds_sum || 0) + @device.last_reading.speed
      open_trip.speeds_quantity = (open_trip.speeds_quantity || 0) + 1
      open_trip.average_speed = (open_trip.speeds_sum || 0) / open_trip.speeds_quantity
      open_trip.save! if save_bang
    end

    # PRE: @device.open_trip_event and @previous_reading != @device.last_reading
    def update_trip_suspect(save_bang = true)
      @device.open_trip_event.suspect = !@device.open_trip_event.has_gps? && !@device.last_reading.has_gps?
      @device.open_trip_event.save! if save_bang
    end

  end
end
