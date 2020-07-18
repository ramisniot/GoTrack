require 'simplecov'
require 'minitest/reporters'
require 'minitest/mock'
require 'mocha/mini_test'
require 'sidekiq/testing'
require 'bunny-mock'

ENV['TZ'] = 'UTC'

# require "#{Rails.root}/lib/rabbit_message_producer.rb"
load 'lib/rabbit_message_producer.rb'

RabbitMessageProducer.client = BunnyMock

Sidekiq::Testing.fake!

SimpleCov.start do
  add_filter '/spec/'
  add_filter '/test/'
end unless ENV['NO_COVERAGE']

ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'

Minitest::Reporters.use! [Minitest::Reporters::DefaultReporter.new(color: true,slow_count: 10,slow_suite_count: 5,fast_fail: true)]

Bundler.require(:shoulda)

def pretend_now_is(time)
  now = Time.parse(time.to_s)
  Time.stubs(:now).returns(now)
end
