# frozen_string_literal: true

# Probador de agentes — el lote «Correcciones · <agente>» que se arma solo con cada 👎 es de un
# agente: se liga por id (si el agente cambia de nombre, sigue siendo el mismo lote).
class AddTemplateToAgentTestBatches < ActiveRecord::Migration[7.0]
  def change
    add_reference :agent_test_batches, :tracking_template, foreign_key: true
  end
end
