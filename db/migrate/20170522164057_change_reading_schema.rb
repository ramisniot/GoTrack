class ChangeReadingSchema < ActiveRecord::Migration
  def change
    remove_column :readings, :altitude, :decimal, precision: 20, scale: 16
    remove_column :readings, :speed, :float
    remove_column :readings, :direction, :float
    remove_column :readings, :note, :string
    remove_column :readings, :address, :string, limit: 1024
    remove_column :readings, :notified, :boolean, default: false
    remove_column :readings, :ignition, :boolean
    remove_column :readings, :gpio1, :boolean
    remove_column :readings, :gpio2, :boolean
    remove_column :readings, :geocoded, :boolean, default: false, null: false
    remove_column :readings, :street_number, :string
    remove_column :readings, :street, :string
    remove_column :readings, :place_name, :string
    remove_column :readings, :admin_name1, :string
    remove_column :readings, :power_up, :boolean, default: false
    remove_column :readings, :battery_voltage, :float
    remove_column :readings, :mileage, :float
    remove_column :readings, :mpg, :float
    remove_column :readings, :rpm, :float
    remove_column :readings, :acceleration, :integer
    remove_column :readings, :deceleration, :integer
    remove_column :readings, :rssi, :integer
    remove_column :readings, :fuel_level, :float
    remove_column :readings, :in_motion, :boolean

    add_column :readings, :data, :jsonb, default: {}
  end
end
