class Location < ActiveRecord::Base
  include Geokit::ActsAsMappable

  self.primary_key = :id

  acts_as_mappable lat_column_name: :latitude, lng_column_name: :longitude

  has_many :readings

  NO_ADDRESS = 'No address'.freeze
  MEXICO = 'mexico'.freeze
  NO_STREET = 'No street'.freeze

  def format_address
    return NO_ADDRESS if nil? || full_address.nil?

    street_number = self.street_number.blank? ? '' : self.street_number
    street = self.street.blank? ? NO_STREET : self.street

    location_mexico = state_name.blank? ? city : "#{city} #{state_name}"
    location_usa = state_abbr.blank? ? city : "#{city} #{state_abbr}"

    if is_mexico?
      street == NO_STREET ? location_mexico.to_s : "#{street} #{street_number}, #{location_mexico}"
    else
      street == NO_STREET ? location_usa.to_s : "#{street_number} #{street}, #{location_usa}"
    end
  end

  private

  def is_mexico?
    full_address.downcase.include?(MEXICO) ||
    (country.present? && country.downcase.include?(MEXICO)) ||
    (state_abbr.present? && state_abbr.length > 2)
  end
end
