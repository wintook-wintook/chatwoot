# frozen_string_literal: true

# @tickets_cases — Clasificación por tipo de caso (Plan-Clase-Comercial F2).
# `case_type_id` NULL = global (aplica a todos los tipos): así queda todo lo que
# ya existe, sin migrar datos. Con valor, el servicio/categoría solo se ofrece
# para ese tipo. Las subcategorías heredan el tipo de su categoría padre.
# Al borrar el tipo, sus servicios/categorías propios se borran (dependent:
# :destroy en CaseType; decisión E del plan).
class AddCaseTypeToCaseClassification < ActiveRecord::Migration[7.0]
  def change
    add_reference :case_services,   :case_type, foreign_key: true, null: true
    add_reference :case_categories, :case_type, foreign_key: true, null: true
  end
end
