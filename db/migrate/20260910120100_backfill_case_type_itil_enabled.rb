# frozen_string_literal: true

# @tickets_cases — Backfill de `case_types.itil_enabled` (paso 2 de 2).
# Los tipos que ya existían antes de esta feature no tenían un modo propio: lo
# heredaban del ajuste de cuenta (CaseSetting#itil_enabled). Para que el deploy
# no cambie nada visualmente, cada tipo hereda exactamente el valor que tenía su
# cuenta al momento de este backfill. `case_settings.itil_enabled` NO se borra
# todavía (eso es un segundo PR, una vez confirmado en producción).
class BackfillCaseTypeItilEnabled < ActiveRecord::Migration[7.0]
  def up
    CaseType.find_each do |case_type|
      itil = case_type.account.case_setting&.itil_enabled || false
      case_type.update_column(:itil_enabled, itil) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def down
    CaseType.update_all(itil_enabled: false) # rubocop:disable Rails/SkipsModelValidations
  end
end
