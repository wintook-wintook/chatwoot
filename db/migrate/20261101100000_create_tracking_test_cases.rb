# proyecto@diagrama_agente_ia F3 — la pila de pruebas guardada por agente (docs/diagrama_agente_ia_plan.md §6).
class CreateTrackingTestCases < ActiveRecord::Migration[7.0]
  def change
    create_table :tracking_test_cases do |t|
      t.references :account, null: false, foreign_key: true
      t.references :tracking_template, null: false, foreign_key: true
      t.text :message, null: false
      # ruta (una por ruta) · regla (una por regla) · propia (escrita a mano)
      t.string :kind, null: false, default: 'propia'
      # La identidad de una prueba generada: «ruta:cotizar», «regla:p1». Generar otra vez no la duplica.
      t.string :source_key
      t.string :expected_route
      t.text :rule
      t.text :check_text
      # Se ofrece en vivo en cada publicación (D5), aunque su camino no cambie.
      t.boolean :pinned, null: false, default: false
      t.integer :position, null: false, default: 0
      # El último resultado y el anterior, en seco y en vivo: { at, ... }. El anterior es el «antes» (F4).
      t.jsonb :last_dry, null: false, default: {}
      t.jsonb :previous_dry, null: false, default: {}
      t.jsonb :last_live, null: false, default: {}
      t.jsonb :previous_live, null: false, default: {}
      t.timestamps
    end
    add_index :tracking_test_cases, [:tracking_template_id, :source_key],
              unique: true, where: 'source_key IS NOT NULL', name: 'index_tracking_test_cases_on_template_and_source_key'
  end
end
