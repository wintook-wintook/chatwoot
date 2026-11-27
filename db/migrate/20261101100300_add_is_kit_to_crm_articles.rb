# CrmZeus A2 — «Juego (kit)» del artículo (ES_JUEGO de Microsip). Por ahora solo la marca;
# los componentes (JUEGOS_DET: artículo, unidades, reemplazable) se traen después.
class AddIsKitToCrmArticles < ActiveRecord::Migration[7.0]
  def change
    add_column :crm_articles, :is_kit, :boolean, null: false, default: false
  end
end
