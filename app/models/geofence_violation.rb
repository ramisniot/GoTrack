class GeofenceViolation < ActiveRecord::Base
  belongs_to :device
  belongs_to :geofence

  scope :for_geofence, lambda { |geofence_id| where(geofence_id: geofence_id) }
  scope :by_violation_time, -> { order('violation_time DESC') }
end
