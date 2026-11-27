# proyecto@diagrama_agente_ia F5 — una prueba puede ser un diálogo corto (2–4 mensajes del cliente).
class AddTurnsToTrackingTestCases < ActiveRecord::Migration[7.0]
  def change
    add_column :tracking_test_cases, :turns, :jsonb, null: false, default: []
  end
end
