# frozen_string_literal: true

# Eventos — captar en la expo «acercando el celular»: un enlace de WhatsApp (wa.me con el
# mensaje ya escrito y un código) que se graba en una etiqueta NFC. Quien escribe con ese
# código queda ligado al evento (asistió), etiquetado y, si el enlace es de un vendedor,
# asignado a él.
class CreateEventCaptureLinks < ActiveRecord::Migration[7.0]
  def change
    create_table :event_capture_links do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :event, null: false, foreign_key: { on_delete: :cascade }
      t.references :inbox, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :code, null: false
      t.text :message, null: false
      t.integer :captures_count, null: false, default: 0
      t.timestamps
    end
    add_index :event_capture_links, :code, unique: true
  end
end
