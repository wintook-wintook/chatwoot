# @tickets_cases — Plan-Plantilla-Tareas-Etapa T1: qué pasa al terminar las tareas
# obligatorias de la etapa: 0 sugerir (defecto), 1 automático, 2 manual.
class AddAdvanceModeToCaseTypeColumns < ActiveRecord::Migration[7.0]
  def change
    add_column :case_type_columns, :advance_mode, :integer, null: false, default: 0
  end
end
