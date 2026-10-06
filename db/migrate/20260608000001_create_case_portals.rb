# frozen_string_literal: true

# @tickets_cases — User Portal (P1)
# Superficie pública del cliente, estilo osTicket. Cada cuenta puede tener un portal
# resuelto por `slug` (ej. /portal/kontrolya). `custom_domain` queda listo para fases
# posteriores (subdominio/marca blanca), reusando el patrón del Help Center.
class CreateCasePortals < ActiveRecord::Migration[7.0]
  def change
    create_table :case_portals do |t|
      t.references :account, null: false, foreign_key: true
      t.references :inbox, null: true, foreign_key: true # inbox "Portal" (Channel::Api)
      t.string  :name, null: false
      t.string  :slug, null: false
      t.string  :custom_domain
      t.string  :locale, null: false, default: 'es'
      t.boolean :enabled, null: false, default: true
      t.text    :intro # texto de bienvenida / branding ligero

      t.timestamps
    end

    add_index :case_portals, :slug, unique: true
    add_index :case_portals, :custom_domain, unique: true, where: 'custom_domain IS NOT NULL'
  end
end
