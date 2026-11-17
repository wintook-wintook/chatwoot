# frozen_string_literal: true

# Probador de agentes — las correcciones van en un lote por agente y por día; una corrida puede
# juntar las pruebas de varios lotes («Correr todas las correcciones de este agente»).
class DailyCorrectionBatches < ActiveRecord::Migration[7.0]
  def change
    add_column :agent_test_batches, :day, :date
    add_index :agent_test_batches, [:tracking_template_id, :day]
    add_column :agent_test_runs, :case_ids, :jsonb, default: [], null: false
    add_column :agent_test_runs, :label, :string
  end
end
