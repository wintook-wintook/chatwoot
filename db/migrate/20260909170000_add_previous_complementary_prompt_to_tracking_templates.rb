# proyecto@asistente_agentes_ia — al reemplazar el Entrenamiento de un agente que ya
# está en producción se guarda el anterior. Es una columna y no una tabla de versiones
# porque lo que hace falta es poder volver atrás UNA vez, en el momento: si el
# Entrenamiento nuevo sale peor, se revierte sin depender de que alguien haya copiado
# el viejo a mano antes de guardar.
class AddPreviousComplementaryPromptToTrackingTemplates < ActiveRecord::Migration[7.0]
  def change
    add_column :tracking_templates, :previous_complementary_prompt, :text
  end
end
