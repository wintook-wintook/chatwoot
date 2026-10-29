# Plan-Eventos E3 — la campaña de un evento: a cuál pertenece y con qué estado de sus
# asistentes (por lote arma la audiencia; continua inscribe a quien llegue a ese estado).
class AddEventToTrackingCampaigns < ActiveRecord::Migration[7.0]
  def change
    add_reference :tracking_campaigns, :event, foreign_key: { on_delete: :nullify }
    add_column :tracking_campaigns, :event_status, :string
  end
end
