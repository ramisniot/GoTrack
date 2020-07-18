class GeofencePolypoint < ActiveRecord::Base
  include Geokit::ActsAsMappable

  acts_as_mappable lat_column_name: :latitude, lng_column_name: :longitude

  belongs_to :geofence
end
