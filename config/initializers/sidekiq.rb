redis_config = YAML.load(ERB.new(File.read(Rails.root.join('config', 'redis.yml'))).result)[Rails.env].symbolize_keys!

Sidekiq.configure_server do |config|
  config.redis = redis_config

  config.error_handlers << Proc.new { |exception, context| ExceptionNotifier.notify_exception(exception) }
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end
