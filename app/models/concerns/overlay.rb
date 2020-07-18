module Overlay
  extend ActiveSupport::Concern
  include Geokit::ActsAsMappable

  MILES_TO_DEGREES = 0.0144927536231884
  MAX_LONGITUDE = 180
  MIN_LONGITUDE = -180
  MAX_LATITUDE = 90
  MIN_LATITUDE = -90
  TOTAL_EARTH_DEGREES = 360

  included do
    acts_as_mappable lat_column_name: :latitude, lng_column_name: :longitude

    scope :not_null, lambda { |attribute| where(self.arel_table[attribute].not_eq(nil)) }
    scope :with_latitude_and_longitude, -> { not_null(:latitude).not_null(:longitude) }

    after_initialize do
      if latitude && longitude
        self.address ||= "#{latitude},#{longitude}"
      end
    end
  end

  module ClassMethods
    def within_latitudes(min_latitude, max_latitude, sql = "latitude >= ? AND latitude <= ?")
      where(sql, min_latitude, max_latitude)
    end

    def within_longitudes(min_longitude, max_longitude, sql = "(longitude >= ? AND longitude <= ?)")
      within_longitudes_sql = sql
      longitudes = [min_longitude, max_longitude]
      if max_longitude < min_longitude
        within_longitudes_sql = "(#{within_longitudes_sql} OR #{within_longitudes_sql})"
        longitudes = [min_longitude, Overlay::MAX_LONGITUDE, Overlay::MIN_LONGITUDE, max_longitude]
      end
      where(within_longitudes_sql, *longitudes)
    end

    def in_bounds(north_west, south_east)
      within_longitudes(north_west.first, south_east.first).within_latitudes(south_east.last, north_west.last)
    end
  end
end
