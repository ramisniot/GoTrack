require_relative 'spanning'

module EventState
  class Base
    include EventState::Spanning

    attr_reader :device, :previous_reading
    attr_accessor :firmware_version

    @@cache_mutex = Mutex.new
    @@state_cache = {}

    class << self

      def for_device(device, &block)
        for_thing_token(device.thing_token, device, &block)
      end

      def for_thing_token(thing_token, device = nil, &block)
        raise 'no thing_token given' unless thing_token
        state = nil
        @@cache_mutex.synchronize do
          state = @@state_cache[thing_token] ||= new(device || block.call)
          Rails.logger.info "ERROR/WARNING: thing_token '#{thing_token}' expected, but thing_token '#{state.device.thing_token}' found" unless thing_token == state.device.thing_token
          Rails.logger.info "ERROR/WARNING: Lock encountered for THING TOKEN #{thing_token}" if state.locked?
          Rails.logger.info "#{$$} - state_cache count: #{@@state_cache.count}"
          state.lock
        end
        block.call(state)
        nil
      ensure
        state.unlock if state and state.locked?
      end

      def exists_for_thing_token?(thing_token)
        @@state_cache.has_key?(thing_token)
      end

      def reset_cache
        @@cache_mutex.synchronize do
          @@state_cache.values.each do |state|
            Rails.logger.info "ERROR saving device with thing_token #{state.device.thing_token}" unless state.device.save(validate: false)
          end
          @@state_cache = {}
          self.open_trip_heap = nil
        end
      end

      def forget_device(device)
        @@cache_mutex.synchronize { @@state_cache.delete device.thing_token }
      end
    end

    def initialize(device)
      raise 'device not found' unless @device = device
      @previous_reading = @device.last_reading
      @instance_mutex = Mutex.new
    end

    def locked?
      @instance_mutex.locked?
    end

    def lock
      @instance_mutex.lock
    end

    def unlock
      @instance_mutex.unlock
    end

  end
end
