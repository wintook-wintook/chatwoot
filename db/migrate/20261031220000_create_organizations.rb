# Plan-Organizaciones O1 — la empresa o el público en general que es prospecto o cliente,
# con sus contactos ligados. El contacto (la persona) no cambia: solo apunta a ella.
class CreateOrganizations < ActiveRecord::Migration[7.0]
  def change
    create_organizations
    add_index :organizations, [:account_id, :stage]
    add_index :organizations, [:account_id, :tax_id], unique: true, where: 'tax_id IS NOT NULL'
    create_organization_events
    add_reference :contacts, :organization, foreign_key: { on_delete: :nullify }
  end

  private

  def create_organizations
    create_table :organizations do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :stage, null: false, default: 0
      t.integer :kind, null: false, default: 0
      t.string :tax_id
      t.string :website
      t.string :email_domain
      t.string :industry
      t.string :phone_number
      t.text :address
      t.references :owner, foreign_key: { to_table: :users, on_delete: :nullify }
      t.jsonb :custom_attributes, null: false, default: {}
      t.text :notes
      t.datetime :became_prospect_at
      t.datetime :became_customer_at
      t.timestamps
    end
  end

  # Quién cambió la etapa o el tipo, y cuándo.
  def create_organization_events
    create_table :organization_events do |t|
      t.references :organization, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :action, null: false
      t.jsonb :data, null: false, default: {}
      t.datetime :created_at, null: false
    end
  end
end
