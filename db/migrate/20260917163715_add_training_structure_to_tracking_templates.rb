# proyecto@asistente_agentes_ia — plan: docs/formulario_entrenamiento_plan.md
# El Entrenamiento de un Agente IA como lista de bloques (ramas, texto inicial,
# secciones), guardado junto al texto que lee el motor. Lo mantiene sincronizado el
# modelo (TrackingTemplate#sync_training_structure); los agentes que ya existen se
# llenan con la tarea agentes_ia:training_structure:backfill.
class AddTrainingStructureToTrackingTemplates < ActiveRecord::Migration[7.0]
  def change
    add_column :tracking_templates, :training_structure, :jsonb, default: {}, null: false
  end
end
