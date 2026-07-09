# frozen_string_literal: true

# @query_databases — tipo de ERP (para sembrar la librería correcta) + sufijo de empresa
# (SAE usa tablas con sufijo: CLIE01, FACTF01).
class AddErpTypeToExternalDbConnections < ActiveRecord::Migration[7.0]
  def change
    add_column :external_db_connections, :erp_type, :integer, null: false, default: 0 # generic
    add_column :external_db_connections, :company_suffix, :string
  end
end
