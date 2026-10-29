# Contratos ligados a un producto del catálogo: si siguen su precio, cambiarlo en el
# catálogo los actualiza. Los que ya existen quedan con su precio fijo.
class AddPriceFromCatalogToContracts < ActiveRecord::Migration[7.0]
  def change
    add_column :contracts, :price_from_catalog, :boolean, default: false, null: false
  end
end
