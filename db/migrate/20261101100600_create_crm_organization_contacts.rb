# CrmZeus C0 — liga entre un contacto de Wintook y su organización de CrmZeus.
# Solo ids: los datos de la persona viven en `contacts`. Un contacto pertenece a una sola organización.
class CreateCrmOrganizationContacts < ActiveRecord::Migration[7.0]
  def change
    create_table :crm_organization_contacts do |t|
      t.references :account, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: { to_table: :crm_organizations, on_delete: :cascade }
      t.references :contact, null: false, type: :integer, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.timestamps
    end
  end
end
