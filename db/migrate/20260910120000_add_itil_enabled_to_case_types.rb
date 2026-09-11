# frozen_string_literal: true

# @tickets_cases — ITIL configurable por tipo de caso (antes era global de cuenta,
# ver CaseSetting#itil_enabled). Cada tipo decide si maneja el modo ITIL (13
# estados, campos de clasificación) o el modo simple. Paso 1 de 2: agrega la
# columna con default `false`; el backfill (que copia el valor que tenía cada
# cuenta) va en una migración aparte para poder revisarlo/reintentarlo solo.
class AddItilEnabledToCaseTypes < ActiveRecord::Migration[7.0]
  def change
    add_column :case_types, :itil_enabled, :boolean, default: false, null: false
  end
end
