# frozen_string_literal: true

# @tickets_cases — Backfill de columnas del Kanban por tipo (Opción A+).
# Los tipos que ya existían ANTES de esta feature (incluidos los de producción)
# nacieron sin columnas propias. Esta migración les siembra las columnas por
# defecto (espejo del tablero fijo: simple 5 / ITIL 6, según el modo de cada
# cuenta), igual que ahora hace el callback al crear un tipo nuevo.
#
# Idempotente: solo actúa sobre tipos que NO tienen ninguna columna, así que es
# seguro aunque una cuenta ya haya configurado columnas a mano antes del deploy.
class BackfillDefaultCaseTypeColumns < ActiveRecord::Migration[7.0]
  def up
    CaseType.find_each do |case_type|
      next if case_type.case_type_columns.exists?

      # Modo de la cuenta sin crear el registro de ajustes si no existe (default: simple).
      itil = case_type.account.case_setting&.itil_enabled || false
      CaseTypeColumn.seed_defaults_for(case_type, itil: itil)
    end
  end

  def down
    # No se revierte: no hay forma de distinguir las columnas sembradas por el
    # backfill de las que un admin pudo editar después. Borrar a ciegas sería peor.
    raise ActiveRecord::IrreversibleMigration
  end
end
