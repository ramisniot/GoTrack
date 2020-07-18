class AddMapDefaultCenterToAccounts < ActiveRecord::Migration
  def change
    change_table :accounts do |t|
      t.decimal :default_map_latitude, precision: 15, scale: 10
      t.decimal :default_map_longitude, precision: 15, scale: 10
    end
  end
end
