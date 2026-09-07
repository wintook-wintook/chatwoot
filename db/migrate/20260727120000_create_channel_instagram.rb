class CreateChannelInstagram < ActiveRecord::Migration[7.0]
  def change
    create_table :channel_instagram do |t|
      t.integer :account_id, null: false
      t.string :access_token, null: false
      t.string :instagram_id, null: false
      t.datetime :expires_at
      t.jsonb :provider_config, default: {}

      t.timestamps
    end

    # Un IGSID solo puede estar conectado a un canal nativo. Es la primera barrera contra
    # la doble entrega de eventos durante la convivencia con la ruta legacy.
    add_index :channel_instagram, :instagram_id, unique: true
    add_index :channel_instagram, [:account_id, :instagram_id], unique: true
  end
end
