class MakeReadingSpeedInteger < ActiveRecord::Migration
  def up
    change_column :readings,:speed, :integer
  end

  def down
    change_column :readings,:speed, :float
  end
end
