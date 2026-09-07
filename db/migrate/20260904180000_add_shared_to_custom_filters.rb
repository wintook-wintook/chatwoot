# @tickets_cases — filtros guardados de tickets (F1)
#
# `shared` distingue una vista personal de una compartida con toda la cuenta.
# El default es false a proposito: lo heredan todas las filas que ya existen,
# asi que las carpetas de Conversaciones, Contactos e Informes siguen
# viendose exactamente igual cuando el index pase a "mias + compartidas" (F2).
class AddSharedToCustomFilters < ActiveRecord::Migration[7.0]
  def change
    add_column :custom_filters, :shared, :boolean, default: false, null: false

    # El indice sirve al scope de F2, que busca las compartidas de la cuenta sin
    # importar de quien sean.
    add_index :custom_filters, [:account_id, :filter_type, :shared],
              name: 'index_custom_filters_on_account_type_shared'
  end
end
