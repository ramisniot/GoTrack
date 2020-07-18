class AddCollectionTokenToAccount < ActiveRecord::Migration
  def change
    add_column :accounts, :collection_token, :string, limit: 250
    add_index :accounts, :collection_token, name: :collection_token_index, unique: true
  end
end
