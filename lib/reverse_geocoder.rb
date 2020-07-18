require 'net/http'
require 'json'

class ReverseGeocoder
  def self.find_all_reading_addresses(reading_ids)
    reading_ids.each { |reading_id| ReverseGeocoderWorker.perform_async(reading_id) }
  rescue Redis::CannotConnectError
    Rails.logger.error("REDIS CONNECTION ERROR: #{$!}")
  end

  def self.find_address_for_reading(reading)
    return unless reading and reading.valid_lat_and_lng?

    body = JSON.dump(lat: reading.latitude, lng: reading.longitude)
    response = QiotApi.apply_reverse_geocoding(body)

    Rails.logger.error("REVERSE GEOCODING SERVICE ERROR: #{response[:error]}") and return nil unless response[:success]

    data = response[:data]
    update_reading(reading, data)

    Rails.logger.info("RG success for #{reading.id} with lat #{reading.latitude} lng #{reading.longitude}")
    reading
  rescue
    Rails.logger.error("REVERSE GEOCODING WORKER ERROR: #{$!}")
    raise
  end

  private

  def self.update_reading(reading, data)
    data.symbolize_keys!

    city = data[:city]
    zip = data[:postal_code]
    country = data[:country_long]
    full_address = data[:address]
    street = data[:route]
    state_name = data[:state_long]
    county = data[:county]
    state_abbr = data[:state_short]
    street_number = data[:street_number]

    ActiveRecord::Base.transaction do
      location = Location.create(
        latitude: reading.latitude,
        longitude: reading.longitude,
        city: city,
        zip: zip,
        country: country,
        full_address: full_address,
        street: street,
        state_name: state_name,
        county: county,
        state_abbr: state_abbr,
        street_number: street_number
      )

      reading.update_attributes(location_id: location.id)
    end
  end
end
