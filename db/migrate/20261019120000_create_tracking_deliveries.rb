# proyecto@automatizacion_campanas — Fase 1 (docs/campanas_agentes_ia_capacidad_plan.md §13):
# un registro por cada envío real de un seguimiento por WhatsApp, para saber si llegó
# (webhook de estado de Meta), reintentar solo lo temporal y nunca reenviar lo entregado.
# Además, la pausa de campaña por error de configuración de Meta y su reanudación.
class CreateTrackingDeliveries < ActiveRecord::Migration[7.0]
  def change
    create_deliveries
    add_index :tracking_deliveries, :source_id
    add_index :tracking_deliveries, [:tracking_campaign_id, :status]
    add_index :tracking_deliveries, :sent_at, where: "status = 'sent'", name: 'index_tracking_deliveries_pending_confirmation'

    add_column :tracking_campaigns, :paused_reason, :string
    add_column :tracking_campaigns, :paused_at, :datetime
    add_column :contact_trackings, :paused_by_campaign, :boolean, null: false, default: false
  end

  private

  def create_deliveries
    create_table :tracking_deliveries do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :contact_tracking, null: false, foreign_key: { on_delete: :cascade }
      t.references :tracking_campaign, foreign_key: { on_delete: :nullify }
      t.references :message, foreign_key: { on_delete: :nullify }, index: { unique: true }
      t.integer :attempt_number, null: false
      t.integer :repetition, null: false, default: 0
      t.integer :retry_count, null: false, default: 0
      t.string :kind, null: false
      t.string :status, null: false, default: 'sent'
      t.string :source_id, :error_code, :error_kind
      t.text :error_title
      t.datetime :next_retry_at, :sent_at, :delivered_at, :read_at, :failed_at
      t.timestamps
    end
  end
end
