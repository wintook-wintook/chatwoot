# Plan-Trabajo-Campo R5 — portal del cliente y técnicos externos:
#   · visit_response: lo que el cliente contestó de su visita (confirmó / pide otra fecha);
#   · csat_*: su calificación del servicio al terminar;
#   · external_*: técnico externo sin usuario, con un enlace que sirve hasta terminar la visita.
class AddFieldPortalData < ActiveRecord::Migration[7.0]
  def change
    change_table :case_tickets, bulk: true do |t|
      t.jsonb :visit_response, null: false, default: {}
      t.integer :csat_rating
      t.text :csat_comment
      t.datetime :csat_at
      t.jsonb :external_technician, null: false, default: {}
      t.string :external_token
      t.datetime :external_token_expires_at
    end
    add_index :case_tickets, :external_token, unique: true
  end
end
