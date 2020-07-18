require 'json'

module RabbitMessageProducer
  def self.client=(client)
    @@client = client
  end

  def self.start
    config = {
      host: RABBITMQ_HOST,
      port: RABBITMQ_PORT,
      user: RABBITMQ_USER,
      pass: RABBITMQ_PASSWORD
    }
    @@conn = @@client.new(ENV['CLOUDAMQP_URL'] || config)
    @@conn.start

    ch = @@conn.create_channel
    @@exchange = ch.direct(RABBITMQ_PASSWORD_MESSAGES_CHANNEL)

  rescue Bunny::PossibleAuthenticationFailureError, Bunny::TCPConnectionFailed, Bunny::NetworkFailure => error
    Rails.logger.error "Could not connect to RabbitMQ: #{error}"
  end

  def self.check_producer_started
    self.start unless defined? @@exchange
  end

  def self.publish(message)
    self.check_producer_started

    return [false, "Unable to connect to RabbitMQ"] unless defined? @@exchange

    data = JSON.dump(message)
    # Get device id from message thing_token (device_token)
    token = message[:thing][:thing_token]

    token_ascii_value = token.each_byte.to_a.reduce(&:+)

    instance_number = token_ascii_value % RABBITMQ_CONSUMER_INSTANCES

    # Always assign a device's messages the same routing key to be
    # consumed by the same consumer
    @@exchange.publish(data, routing_key: instance_number, persistent: true)
    Rails.logger.info " [x] Sent '#{data}'"
  end

  def self.shutdown
    @@conn.close
  end

  def self.publish_forget_device(thing_token)
    publish(type: {action: 'forget_device'}, thing: {thing_token: thing_token})
  end

  def self.publish_clear_device_history(thing_token)
    publish(type: {action: 'clear_history'}, thing: {thing_token: thing_token})
  end
end
