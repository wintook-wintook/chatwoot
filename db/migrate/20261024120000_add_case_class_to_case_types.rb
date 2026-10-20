# frozen_string_literal: true

# @tickets_cases — Clase de caso (Plan-Clase-Comercial F1). Nivel por encima del
# Tipo: Soporte / Comercial / Orden de trabajo / Proyecto. Cada clase tiene su
# propio comportamiento en código; el tipo solo declara a cuál pertenece y el
# ticket la hereda de su tipo. Default 0 = soporte → todos los tipos existentes
# quedan como Soporte sin backfill y nada cambia para ellos.
class AddCaseClassToCaseTypes < ActiveRecord::Migration[7.0]
  def change
    add_column :case_types, :case_class, :integer, default: 0, null: false
    add_index  :case_types, [:account_id, :case_class]
  end
end
