class ReInsertReadingBatteryVoltage < ActiveRecord::Migration
  def change
    add_column :readings,:battery_voltage,:float,limit: 24
  end
end
