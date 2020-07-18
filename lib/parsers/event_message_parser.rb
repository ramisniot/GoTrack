require 'json'

module EventMessageParser
  def self.parse(event_message)
    message     = JSON.parse(event_message)
    event_type  = message['type']['action']
    token       = message['thing']['thing_token']
    case event_type
      when /^log$/i           then  parse_message(token, message)
      when /^forget_device$/i then  forget_device(token)
      when /^clear_history$/i then  clear_history(token)
      else                          parse_thing(token, message['thing'])
    end
  rescue
    Rails.logger.error "EVENT MESSAGE PARSER ERROR: #{$!}"
    ExceptionNotifier.notify_exception($!)
  end

  def self.parse_message(token, event_message)
    return Rails.logger.info "No messages given" unless (messages = event_message['messages']).kind_of?(Array) and messages.any?

    EventState::Base.for_thing_token(token) do |event_state|
      if event_state.nil?
        Device.find_by(thing_token: token)
      else
        server_time = Reading.parse_time(event_message['time']) || Time.now.utc

        messages.each do |message|
          Reading.create_from_message(event_state, server_time, message)
        end
      end
    end
  end

  def self.parse_thing(token, thing)
    imei = thing_imei(thing['identities'] || [])

    name = thing['label']
    collection_token = thing['collection_token']

    account = Account.find_by(collection_token: collection_token) if collection_token

    device_attrs = { name: name, imei: imei, account_id: account ? account.id : 0}

    if device = Device.find_by(thing_token: token)
      device_attrs[:provision_status_id] = ProvisionStatus::STATUS_DELETED if thing['deleted']
    elsif imei
      device = Device.find_by(imei: imei)

      device_attrs[:thing_token] = token
      device_attrs[:provision_status_id] = thing['deleted'] ? ProvisionStatus::STATUS_DELETED : account ? ProvisionStatus::STATUS_ACTIVE : ProvisionStatus::STATUS_INACTIVE
    end

    if device
      device.update_attributes(device_attrs)
      Rails.logger.info "Updated device with: #{device_attrs.inspect}"
    else
      Device.create(device_attrs)
      Rails.logger.info "Created device with: #{device_attrs.inspect}"
    end
  end

  def self.thing_imei(identities)
    identities.each do |identity|
      return identity['value'] if identity['type'].casecmp('imei').zero?
    end
  end

  def self.forget_device(token)
    EventState::Base.forget_device(Device.find_by(thing_token: token))
  end

  def self.clear_history(token)
    Device.find_by(thing_token: token)&.clear_history(false)
  end
end
