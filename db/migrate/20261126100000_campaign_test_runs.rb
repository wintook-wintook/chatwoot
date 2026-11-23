# frozen_string_literal: true

# Campaña con Vendedor IA — «Prueba real»: una copia de la campaña que solo va a los contactos de prueba, con los
# toques cada pocos minutos. test_of_id liga la copia con la campaña de verdad (y la saca de listados y resultados).
class CampaignTestRuns < ActiveRecord::Migration[7.0]
  def change
    add_reference :tracking_campaigns, :test_of, foreign_key: { to_table: :tracking_campaigns, on_delete: :cascade }, index: true
  end
end
