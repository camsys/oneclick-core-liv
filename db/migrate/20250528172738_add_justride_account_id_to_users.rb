class AddJustrideAccountIdToUsers < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :justride_account_id, :string
    add_index :users, :justride_account_id
  end
end
