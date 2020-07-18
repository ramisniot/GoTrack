class AddThingTokenToDevices < ActiveRecord::Migration
  def change
    add_column :devices, :thing_token, :string, limit: 250
  end
end
