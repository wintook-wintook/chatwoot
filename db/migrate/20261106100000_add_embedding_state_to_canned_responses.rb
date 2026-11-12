# frozen_string_literal: true

# proyecto@respuestas_predefinidas R1 (docs/respuestas_predefinidas_plan.md §3–4): el estado
# de vectorización de cada predefinida, para que se vea si está en la fuente de datos del
# agente. Idempotente: hay bases donde la tabla trae columnas del sistema anterior.
class AddEmbeddingStateToCannedResponses < ActiveRecord::Migration[7.0]
  def change
    add_column :canned_responses, :embedding_status, :string unless column_exists?(:canned_responses, :embedding_status)
    add_column :canned_responses, :embedding_error, :string unless column_exists?(:canned_responses, :embedding_error)
    add_column :canned_responses, :embedded_at, :datetime unless column_exists?(:canned_responses, :embedded_at)
  end
end
