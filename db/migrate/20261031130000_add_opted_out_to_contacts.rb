# prospeccion V4 — lista de no contactar. La baja es por contacto y vale en todos los
# canales (D11): ninguna campaña lo vuelve a inscribir y sus seguimientos se cancelan.
# opted_out_source: 'link' (enlace del correo), 'reply' (lo pidió al responder), 'agent' (a mano).
class AddOptedOutToContacts < ActiveRecord::Migration[7.0]
  def change
    add_column :contacts, :opted_out_at, :datetime
    add_column :contacts, :opted_out_source, :string
  end
end
