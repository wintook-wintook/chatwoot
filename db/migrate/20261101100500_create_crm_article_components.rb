# CrmZeus A3 — componentes de un artículo kit (JUEGOS_DET de Microsip): artículo, unidades,
# reemplazable y si se pueden cambiar las unidades al cotizar. Un kit no lleva kits dentro.
class CreateCrmArticleComponents < ActiveRecord::Migration[7.0]
  def change
    create_table :crm_article_components do |t|
      t.references :account, null: false, foreign_key: true
      t.references :article, null: false, foreign_key: { to_table: :crm_articles, on_delete: :cascade }
      # Restrict: un artículo que es componente de un kit no se borra (la API avisa en cuál).
      t.references :component, null: false, foreign_key: { to_table: :crm_articles }
      t.decimal :quantity, precision: 18, scale: 5, null: false, default: 1
      t.boolean :replaceable, null: false, default: false
      t.boolean :units_editable, null: false, default: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :crm_article_components, %i[article_id component_id], unique: true
  end
end
