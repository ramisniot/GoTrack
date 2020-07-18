# config/initializers/messages_producer.rb

unless Rails.env.test?
  require 'bunny'

  require "#{Rails.root}/lib/rabbit_message_producer.rb"

  RabbitMessageProducer.client = Bunny
  RabbitMessageProducer.start
  at_exit { RabbitMessageProducer.shutdown }
end
