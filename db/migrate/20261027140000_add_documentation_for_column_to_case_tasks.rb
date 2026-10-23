# @tickets_cases — Plan-Plantilla-Tareas-Etapa T3: la tarea obligatoria «Documenta…»
# recuerda a qué etapa lleva. No se palomea a mano: se completa sola cuando el caso
# sale de su etapa (al documentar el cierre, el resultado o la fecha).
class AddDocumentationForColumnToCaseTasks < ActiveRecord::Migration[7.0]
  def change
    add_reference :case_tasks, :documentation_for_column, foreign_key: { to_table: :case_type_columns, on_delete: :nullify },
                                                          index: false
  end
end
