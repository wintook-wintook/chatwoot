# @tickets_cases — «Resumen del negocio»: además de los administradores (que
# siempre lo ven), los agentes que el administrador autorice con una casilla.
class AddBusinessSummaryUserIdsToCaseSettings < ActiveRecord::Migration[7.0]
  def change
    add_column :case_settings, :business_summary_user_ids, :bigint, array: true, default: [], null: false
  end
end
