# CrmZeus Q4.0 — página pública de la cotización (`/cotizacion-crm/:token`, como `quotes` de develop):
# token por cotización (se llenan las que ya existen) y el parámetro «Mostrar componentes de los kits»
# (`showArtComps` de master2, que allá era preferencia por usuario; apagado por omisión). El texto de la
# moneda por omisión pasa al formato de master2 `PESOS/M.N.` (lo de antes de «/» va antes de los centavos).
class AddPublicTokenToCrmQuotes < ActiveRecord::Migration[7.0]
  class Quote < ApplicationRecord
    self.table_name = 'crm_quotes'
  end

  def up
    add_column :crm_quotes, :public_token, :string
    Quote.where(public_token: nil).find_each { |quote| quote.update_column(:public_token, SecureRandom.base58(24)) } # rubocop:disable Rails/SkipsModelValidations
    change_column_null :crm_quotes, :public_token, false
    add_index :crm_quotes, :public_token, unique: true

    add_column :crm_settings, :show_kit_components, :boolean, null: false, default: false
    execute "UPDATE crm_currencies SET amount_in_words = 'PESOS/M.N.' WHERE amount_in_words = 'pesos M.N.'"
  end

  def down
    execute "UPDATE crm_currencies SET amount_in_words = 'pesos M.N.' WHERE amount_in_words = 'PESOS/M.N.'"
    remove_column :crm_settings, :show_kit_components
    remove_index :crm_quotes, :public_token
    remove_column :crm_quotes, :public_token
  end
end
