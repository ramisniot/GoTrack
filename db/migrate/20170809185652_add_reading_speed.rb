class AddReadingSpeed < ActiveRecord::Migration
  def change
    add_column :readings, :speed, :float
  end
end
