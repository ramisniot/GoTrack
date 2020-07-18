class AddAccountContactFields < ActiveRecord::Migration
  def change
    change_table :accounts do |t|
      t.string :contact_name
      t.string :contact_email
      t.string :contact_phone
    end
  end
end
