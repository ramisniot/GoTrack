class ReverseGeocoderWorker
  include Sidekiq::Worker

  sidekiq_options retry: false

  sidekiq_retries_exhausted do |message|
    reading = Reading.find_by(id: message['args'].first)
    Rails.logger.error("Reverse geocoding service failed for reading #{reading.id} with lat #{reading.latitude} lng #{reading.longitude}")
  end

  def perform(reading_id)
    ReverseGeocoder.find_address_for_reading(Reading.find_by(id: reading_id))
  end
end
