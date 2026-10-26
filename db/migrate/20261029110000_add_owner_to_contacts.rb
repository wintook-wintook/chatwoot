# Responsable fijo del contacto: sus conversaciones (y sus casos nuevos) van
# siempre con esta persona, sin importar las reglas de asignación.
class AddOwnerToContacts < ActiveRecord::Migration[7.0]
  def change
    add_reference :contacts, :owner, foreign_key: { to_table: :users, on_delete: :nullify }
  end
end
