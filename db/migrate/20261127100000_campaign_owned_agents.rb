# frozen_string_literal: true

# Campaña con Vendedor IA: cada campaña arma su propio agente («Cómo atiende» en la campaña). Es un tracking_template
# 2.0 como cualquier otro para el motor, pero campaign_owned: no sale en las listas de agentes ni se elige en otro lado.
class CampaignOwnedAgents < ActiveRecord::Migration[7.0]
  def change
    add_column :tracking_templates, :campaign_owned, :boolean, null: false, default: false
    add_index :tracking_templates, %i[account_id campaign_owned]
  end
end
