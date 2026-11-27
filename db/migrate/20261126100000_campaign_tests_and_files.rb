# frozen_string_literal: true

# Campaña con Vendedor IA:
#   · «Prueba real»: una copia de la campaña que solo va a los contactos de prueba, con los toques cada pocos minutos.
#     test_of_id liga la copia con la campaña de verdad (y la saca de listados y resultados).
#   · «Imágenes y archivos de esta oferta»: los archivos de la campaña van en la misma tabla que los del vendedor
#     (ai_agent_attachments), ligados a la campaña y con su regla (rules: en qué toques, al mostrar interés…).
class CampaignTestsAndFiles < ActiveRecord::Migration[7.0]
  def change
    add_reference :tracking_campaigns, :test_of, foreign_key: { to_table: :tracking_campaigns, on_delete: :cascade }, index: true
    add_reference :ai_agent_attachments, :tracking_campaign, foreign_key: { on_delete: :cascade }, index: true
    add_column :ai_agent_attachments, :rules, :jsonb, null: false, default: {}
    add_index :ai_agent_attachments, [:tracking_campaign_id, :name], unique: true, name: 'index_ai_agent_attachments_on_campaign_and_name'
    change_column_null :ai_agent_attachments, :tracking_template_id, true
  end
end
