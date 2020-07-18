class DeviceTypeProperties
  extend Settings

  PROPERTIES = [:enabled,
                :gateway_name,
                :label,
                :identifier_label,
                :identifier_regex,
                :network,
                :power,
                :supports_on_device_activation,
                :supports_on_network_activation,
                :supports_on_device_geofences,
                :supports_motion,
                :supports_speed,
                :supports_speed_threshold,
                :speed_deadband,
                :supports_locate_now,
                :door_unlock_index,
                :supports_track_now,
                :supports_panic,
                :supports_vehicle_disable,
                :supports_digital_sensors,
                :supports_ignition,
                :supports_telematics,
                :suspect_ignition,
                :max_digital_sensors,
                :supports_tank_level,
                :supports_temperature,
                :supports_battery_level,
                :battery_level_type,
                :battery_level_units,
                :battery_level_threshold,
                :compute_battery_usage,
                :expected_readings_per_battery,
                :internal_battery_level_units,
                :internal_battery_level_threshold]

  attr_reader :name
  PROPERTIES.each { |property| attr_reader property }

  class << self
    def device_types
      @@device_types ||= self.build_device_types
    end

    def build_device_types
      device_types = {}
      settings['gateways'].each do |gateway_name, gateway|
        if(gateway['enabled'])
          gateway['device_types'].each do |key, value|
            if(value['enabled'])
              value['gateway_name'] = gateway_name
              device_types[key] = value
            end
          end
        end
      end
      device_types
    end

    def device_type_names_hash
      @@device_type_names_hash ||= self.build_device_type_names_hash
    end

    def build_device_type_names_hash
      device_type_names_hash = {}
      device_types.each_key do |key|
        device_type_names_hash[key.upcase] = key
      end
      device_type_names_hash
    end

    def by_gateway_name(gateway_name)
      device_type_names_hash.values.collect { |name| by_name(name) }.select { |device_type_properties| device_type_properties.gateway_name == gateway_name }
    end

    def reset
      @@properties_lookup = {}
    end

    # Should be overriden by the app
    def by_name(name)
      unless(device_types[name])
        properties = {}
        PROPERTIES.each do |property|
          properties[property] = nil
        end
        return new(name, properties)
      end
      @@properties_lookup[name] ||= new(name, device_types[name])
    end

  end

  DeviceTypeNames = EnumFactory.factory('DeviceTypeNames', :name, :id, self.device_type_names_hash)

  reset

  def initialize(name, device_type)
    @name = name

    validate_properties(device_type)
    set_capabilities(device_type)
  end

  protected

  def set_capabilities(properties = {})
    PROPERTIES.each { |property| self.instance_variable_set("@#{property.to_s}", properties[property.to_s]) }
  end

  def validate_properties(properties = {})
    properties.each do |property, value|
      raise "Property #{property} does not exist in the defined DeviceTypeProperties, please check PROPERTIES constant" unless PROPERTIES.include? property.to_sym
    end
  end
end
