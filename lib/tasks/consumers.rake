namespace :consumers do
  task :save_messages_consumer_start, [:instance_number] => [:environment] do |t, args|
    Rails.logger       = Logger.new(STDOUT) # Logger.new(Rails.root.join('log', 'consumers.log'))
    # Rails.logger.level = Logger.const_get((ENV['LOG_LEVEL'] || 'info').upcase)

    Signal.trap('TERM') { abort }

    Rails.logger.info "Start consumer daemon..."

    $instance_number = args.instance_number
    require "#{Rails.root}/lib/consumers/rabbit_message_consumer.rb"
  end
end
