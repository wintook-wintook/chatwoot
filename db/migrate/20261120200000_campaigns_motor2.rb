# frozen_string_literal: true

# Campañas Motor 2.0 (pantalla nueva, aparte de la 1.0): la campaña trae su oferta (brief) y sus toques
# por canal; el «Vendedor de campaña» (agente 2.0) la atiende. Las de antes quedan en engine '1'.
# tracking_campaign_clicks: cada clic en una liga de un correo de campaña (TrackingCampaigns::ClickLink).
# prospect_lists + contacts.prospect_list_id / list_quarantine: listas de correo frías subidas a una campaña; sus
# contactos nuevos quedan en cuarentena (no salen en Contactos) hasta que contestan, y si nunca contestan se borran.
# email_suppressions: correos que se dieron de baja o rebotaron (no se vuelven a cargar de una lista).
class CampaignsMotor2 < ActiveRecord::Migration[7.0]
  def change
    campaign_columns
    clicks_table
    prospect_lists_table
    contact_columns
    suppressions_table
  end

  private

  def campaign_columns
    change_table :tracking_campaigns, bulk: true do |t|
      t.string :engine, null: false, default: '1'
      t.jsonb :brief, null: false, default: {}
      t.jsonb :touches, null: false, default: {}
    end
  end

  def clicks_table
    create_table :tracking_campaign_clicks do |t|
      t.references :account, null: false, foreign_key: true
      t.references :tracking_campaign, null: false, foreign_key: { on_delete: :cascade }
      t.bigint :contact_tracking_id, null: false
      t.bigint :contact_id, null: false
      t.string :url, null: false, limit: 2000
      t.datetime :created_at, null: false
    end
    add_index :tracking_campaign_clicks, %i[tracking_campaign_id contact_id], name: 'index_campaign_clicks_on_campaign_and_contact'
  end

  def prospect_lists_table
    create_table :prospect_lists do |t|
      t.references :account, null: false, foreign_key: true
      t.references :tracking_campaign, foreign_key: { on_delete: :nullify }
      t.bigint :uploaded_by_id
      t.string :name, null: false
      t.integer :cleanup_days, null: false, default: 30
      t.jsonb :stats, null: false, default: {}
      t.datetime :cleaned_at
      t.timestamps
    end
  end

  def contact_columns
    change_table :contacts, bulk: true do |t|
      t.bigint :prospect_list_id
      t.boolean :list_quarantine, null: false, default: false
    end
    add_index :contacts, %i[account_id list_quarantine], where: 'list_quarantine', name: 'index_contacts_on_list_quarantine'
    add_index :contacts, :prospect_list_id
  end

  def suppressions_table
    create_table :email_suppressions do |t|
      t.references :account, null: false, foreign_key: true
      t.string :email, null: false
      t.string :reason, null: false
      t.datetime :created_at, null: false
    end
    add_index :email_suppressions, %i[account_id email], unique: true
  end
end
