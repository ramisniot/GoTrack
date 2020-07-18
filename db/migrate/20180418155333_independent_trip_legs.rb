class IndependentTripLegs < ActiveRecord::Migration
  def change
    change_table :trip_legs do |t|
      t.integer   :device_id
      t.datetime  :started_at
      t.datetime  :stopped_at
      t.integer   :max_speed
      t.boolean   :suspect
    end

    add_index :trip_legs,%i(device_id started_at)
  end
end
