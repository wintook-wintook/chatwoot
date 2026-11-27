# CrmZeus Q3.1 — MOSTRAR_NOTAS de master2: al elegir el artículo de una partida se ponen sus notas
# (activado por omisión, decisión del usuario).
class AddShowArticleNotesToCrmSettings < ActiveRecord::Migration[7.0]
  def change
    add_column :crm_settings, :show_article_notes, :boolean, null: false, default: true
  end
end
