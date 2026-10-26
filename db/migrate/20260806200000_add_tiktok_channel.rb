class AddTiktokChannel < ActiveRecord::Migration[7.0]
  def change
    create_table :channel_tiktok do |t|
      t.integer :account_id, null: false
      # open_id de la cuenta de empresa: es con lo que llegan los webhooks.
      t.string :business_id, null: false
      t.string :access_token, null: false
      t.datetime :expires_at, null: false
      # TikTok, a diferencia de Meta, da un token corto (~1 día) y otro de refresco con
      # su propia caducidad. Sin el segundo hay que rehacer el OAuth.
      t.string :refresh_token, null: false
      t.datetime :refresh_token_expires_at, null: false

      t.timestamps
    end

    add_index :channel_tiktok, :business_id, unique: true
    add_index :channel_tiktok, [:account_id, :business_id], unique: true
  end
end
