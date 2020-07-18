class CacheDeviceGeofenceReadingState < ActiveRecord::Migration
  def change
    change_table :devices do |t|
      t.decimal :last_geofence_latitude,    precision: 15, scale: 10
      t.decimal :last_geofence_longitude,   precision: 15, scale: 10
      t.float   :last_geofence_speed
    end
  end
end
