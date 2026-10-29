# prospeccion P2 (docs/prospeccion_estudio.md §10.9) — entregar al interesado con plazo y avisos.
#   Campaña:     a qué tablero/columna de Oportunidades entra, plazo y escalar (horas hábiles;
#                vacío = sin plazo / no escalar).
#   Seguimiento: el reloj de su entrega (entregado, vence, escala) y lo que pasó (atendido,
#                recordado, escalado).
class AddHandoffToTrackingCampaigns < ActiveRecord::Migration[7.0]
  def change
    change_table :tracking_campaigns, bulk: true do |t|
      t.bigint :handoff_board_id
      t.bigint :handoff_column_id
      t.integer :handoff_due_hours
      t.integer :handoff_escalate_hours
    end

    change_table :contact_trackings, bulk: true do |t|
      t.datetime :handed_off_at
      t.datetime :handoff_due_at
      t.datetime :handoff_escalate_at
      t.datetime :handoff_attended_at
      t.datetime :handoff_reminded_at
      t.datetime :handoff_escalated_at
    end
    add_index :contact_trackings, :handed_off_at, where: 'handed_off_at IS NOT NULL AND handoff_attended_at IS NULL',
                                                  name: 'index_contact_trackings_on_pending_handoff'
  end
end
