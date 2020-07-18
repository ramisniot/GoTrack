class GatewayProperties
  extend Settings

  PROPERTIES = [:label, :database, :default_device_type]

  attr_reader :name
  PROPERTIES.each { |property| attr_reader property }

  class << self
    def gateways
      @@gateways ||= self.build_gateways
    end

    def build_gateways
      gateways = {}
      settings['gateways'].each do |key, value|
        gateways[key] = value if(value['enabled'])
      end
      gateways
    end

    def gateway_names_hash
      gateway_names_hash = {}
      gateways.each_key do |key|
        gateway_names_hash[key.upcase] = key
      end
      gateway_names_hash
    end

    def all
      gateway_names_hash.values.collect { |name| by_name(name) }
    end

    def reset
      @@properties_lookup = {}
    end

    # Should be overriden by the app
    def by_name(name)
      unless(gateways[name])
        properties = {}
        PROPERTIES.each do |property|
          properties[property] = nil
        end
        return new(name, properties)
      end
      @@properties_lookup[name] ||= new(name, gateways[name])
    end
  end

  def device_types
    DeviceTypeProperties.by_gateway_name(self.name)
  end

  GatewayNames = EnumFactory.factory('GatewayNames', :name, :id, gateway_names_hash)

  reset

  def initialize(name, gateway)
    @name = name
    @label = gateway['label']
    @database = gateway['database']
    @default_device_type = gateway['default_device_type']
  end
end
