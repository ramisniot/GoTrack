class AddThingTokenIndexToDevices < ActiveRecord::Migration
  def change
    add_index :devices, :thing_token, name: :thing_token_index, unique: true
  end
end
