# Plan-Roles-Permisos P1 — roles por cuenta (Supervisor, Vendedor, Técnico, Consulta).
# El Administrador no se guarda: es fijo (account_users.role = administrator).
# Un agente sin access_role_id cuenta como Supervisor, así que no hay que tocar
# los account_users existentes.
class CreateAccessRoles < ActiveRecord::Migration[7.0]
  def change
    create_table :access_roles do |t|
      t.references :account, null: false, foreign_key: true
      t.string :key, null: false
      t.jsonb :areas, null: false, default: {}
      t.jsonb :actions, null: false, default: {}
      t.timestamps
    end
    add_index :access_roles, %i[account_id key], unique: true

    add_reference :account_users, :access_role, foreign_key: { on_delete: :nullify }
  end
end
