source 'https://rubygems.org'

ruby '2.3.7'

gem 'bitmask_attributes'
gem "browser"
gem 'bunny', '>= 2.7.0'
gem 'daemons'
gem 'devise'
gem 'devise-encryptable'
gem 'exception_notification'
gem 'figaro'
gem 'foreman'
gem 'geokit'
gem 'geokit-rails'
gem 'highline'
gem 'hpricot'
gem 'json'
gem 'jquery-rails'
gem 'log4r'
# gem 'mobileappmgr',                 git: 'git@github.com:numerex/mobileappmgr.git',           branch: 'master'
gem 'net-scp'
gem 'pg'
gem 'puma'
gem 'rails', '4.2.7'
gem 'rails-observers'
gem 'ransack' # Support for Model.search(params[:search])
gem 'redcarpet'
gem 'RedCloth'
gem 'sidekiq'
gem 'squeel'
gem 'will_paginate'
gem 'algorithms'
gem 'font-awesome-rails'
gem 'sass-rails'
gem 'redis-rails'

group :development, :staging, :test do
  gem 'bullet'
end

group :development do
  gem 'brakeman', require: false
  gem 'factory_girl'
  gem 'quiet_assets'
  gem 'rdoc'
  gem 'ruby_parser'
  gem 'thin'
end

group :assets do
  gem 'therubyracer'
  gem 'uglifier'
end

group :test do
  gem 'capybara'
  gem 'capybara-screenshot'
  gem 'database_cleaner'
  gem 'factory_girl_rails'
  gem 'guard'
  gem 'guard-minitest'
  gem 'minitest-reporters', require: false
  gem 'mocha'
  gem 'poltergeist'
  gem 'rails-perftest'
  gem 'ruby-prof','=0.15.9' # TODO set to current when https://github.com/rails/rails-perftest/issues/38 is fixed
  gem 'shoulda'
  gem 'simplecov', require: false
end

group :test, :development do
  gem 'bunny-mock'
  gem 'ci_reporter'
  gem 'rubocop'
end
