# CrmZeus A2 — fecha y motivo de baja / suspensión del artículo (FECHA_SUSP, CAUSA_SUSP de
# Microsip), como en las organizaciones. Solo aplican cuando el estatus no es activo.
class AddSuspensionToCrmArticles < ActiveRecord::Migration[7.0]
  def change
    add_column :crm_articles, :suspended_on, :date
    add_column :crm_articles, :suspension_reason, :string, limit: 250
  end
end
