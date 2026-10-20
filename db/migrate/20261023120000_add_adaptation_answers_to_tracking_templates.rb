# frozen_string_literal: true

# proyecto@adaptar_prompts_publicados (F6) — lo último aplicado en la pestaña «Configurar»
# de este agente: { "var:horario" => "L-V 9 a 18", "google_doc:precios" => "Lista 2026" }.
# Cuando el autor publica una versión nueva, la pestaña sale prellenada con esto.
class AddAdaptationAnswersToTrackingTemplates < ActiveRecord::Migration[7.0]
  def change
    add_column :tracking_templates, :adaptation_answers, :jsonb, null: false, default: {}
  end
end
