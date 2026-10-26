# Plan-Trabajo-Campo R2 — portal del técnico: ubicación al llegar y al terminar
# (en la entrada de horas de la visita) y la firma de conformidad del cliente.
class AddFieldVisitData < ActiveRecord::Migration[7.0]
  def change
    add_column :case_time_entries, :location, :jsonb, null: false, default: {}
    add_column :case_tickets, :conformity_signature, :text
  end
end
