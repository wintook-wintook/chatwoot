# frozen_string_literal: true

# Probador de agentes con la búsqueda nueva (proyecto@predefinidas_que_contestan):
#   agent_test_runs.seleccion    con qué búsqueda corrió: nil = la de la cuenta, 'on' = la nueva
#                                (buscar y escoger), 'off' = la de siempre. Sirve para comparar sin
#                                prenderla en la cuenta.
#   agent_test_cases.variables   las variables de la plática al guardar la prueba (CARRERA,
#                                PRODUCTO…): la corrida las pone antes de escribir, para no perder
#                                de qué se hablaba.
#   agent_test_logs.note         «¿Qué estuvo mal?» (opcional) de quien probó; `feedback` es «¿Qué
#                                debió responder?». El diagnóstico lo ve solo quien revisa.
#   agent_test_logs.dismissed_reason  por qué quien revisa dijo «No es error».
class AgentTesterBusquedaNueva < ActiveRecord::Migration[7.0]
  def change
    add_column :agent_test_runs, :seleccion, :string
    add_column :agent_test_cases, :variables, :jsonb, null: false, default: {}
    add_column :agent_test_logs, :note, :text
    add_column :agent_test_logs, :dismissed_reason, :text
  end
end
