class SyncTripLegData < ActiveRecord::Migration
  def up
    TripLeg.where('not exists(select * from trip_events where trip_events.id = trip_event_id)').delete_all
    TripLeg.includes(:trip_event,:reading_start,:reading_stop).each do |leg|
      leg.update_attributes(
          device_id: leg.trip_event.device_id,
          suspect:  leg.trip_event.suspect,
          max_speed: leg.trip_event.max_speed, # NOTE - this may not be accurate, but the alternative is too costly
          started_at: leg.reading_start.recorded_at,
          stopped_at: leg.reading_stop&.recorded_at)
    end
  end

  def down
  end
end
