class AddRtsPurchaseUrlToServices < ActiveRecord::Migration[5.0]
  def change
    add_column :services, :rts_purchase_url, :string
  end
end
