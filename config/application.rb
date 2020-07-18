require File.expand_path('../boot', __FILE__)

require 'rails/all'

if defined?(Bundler)
  # If you precompile assets before deploying to production, use this line
  Bundler.require(*Rails.groups(assets: %w(development test)))
  # If you want your assets lazily compiled in production, use this line
  # Bundler.require(:default, :assets, Rails.env)
end

module GoTrack
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    # config.autoload_paths += %W(#{config.root}/extras)

    config.eager_load_paths += Dir["#{config.root}/lib/parsers/"]
    config.autoload_paths += %W(#{config.root}/lib)

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    config.active_record.observers = :offline_event_email_observer

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de
    config.i18n.enforce_available_locales = false

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = 'utf-8'

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    # Enable escaping HTML in JSON.
    config.active_support.escape_html_entities_in_json = true

    # Use SQL instead of Active Record's schema dumper when creating the database.
    # This is necessary if your schema can't be completely dumped by the schema dumper,
    # like if you have constraints or database-specific column types
    # config.active_record.schema_format = :sql

    # Avoid database connection when precompiling assets
    config.assets.initialize_on_precompile = false

    # Enable the asset pipeline
    config.assets.enabled = true

    config.assets.paths << Rails.root + 'app/assets/javascript/shared'
  end
end

RADIUS_ARRAY = [
  { miles: 0.01, label: '50 ft' },
  { miles: 0.02, label: '100 ft' },
  { miles: 0.1, label: '500 ft' },
  { miles: 0.25, label: '0.25 mi' },
  { miles: 0.5, label: '0.5 mi' },
  { miles: 1, label: '1 mi' },
  { miles: 5, label: '5 mi' },
  { miles: 10, label: '10 mi' },
  { miles: 25, label: '25 mi' },
  { miles: 50, label: '50 mi' },
  { miles: 100, label: '100 mi' }
]

GROUP_IMAGES = ['no_image.png', 'blue_small.png', 'red_small.png', 'green_small.png', 'yellow_small.png', 'purple_small.png', 'dark_blue_small.png', 'grey_small.png', 'orange_small.png', 'destination_small.png']
MAP_MARKER_COLOR = ['blue', 'red', 'green', 'yellow', 'purple', 'black', 'gray', 'orange', 'white', 'brown']

STANDARD_DATE_FORMAT = '%d-%b-%Y'
STANDARD_TIME_FORMAT = '%I:%M %p'
STANDARD_DATETIME_FORMAT = STANDARD_DATE_FORMAT + ' ' + STANDARD_TIME_FORMAT
EMAIL_TIMESTAMP_FORMAT = '%a, %b %e %Y %H:%M:%S %Z'
COMPACT_TIMESTAMP_FORMAT = '%m-%d-%Y %H:%M %Z'

COMPANY = "GoTrackInc"
DOMAIN = "gotrack.com"

# Email addresses
SUPPORT_EMAIL = ENV['SUPPORT_EMAIL'] || 'support@quantumiot.com'
ALERT_EMAIL = ENV['ALERTS_EMAIL'] || 'no-reply@quantumiot.com' #where notifications come from

RESULT_COUNT = 25 # Number of results per page
