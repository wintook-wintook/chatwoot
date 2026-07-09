# frozen_string_literal: true

# @query_databases
# Conexión read-only a la base de datos de un ERP del cliente (Firebird/SQL Server).
# Las credenciales se guardan según la convención de Chatwoot (texto plano, como
# `access_token`/`settings` de integraciones); nunca se exponen en logs ni en el JSON.
#
# == Schema Information
#
# Table name: external_db_connections
#
#  id             :bigint           not null, primary key
#  active         :boolean          default(TRUE), not null
#  company_suffix :string
#  database       :string           not null
#  engine         :integer          default("firebird"), not null
#  erp_type       :integer          default("generic"), not null
#  host           :string           not null
#  name           :string           not null
#  options        :jsonb            not null
#  password       :string
#  port           :integer          not null
#  read_only      :boolean          default(TRUE), not null
#  username       :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :bigint           not null
#
# Indexes
#
#  index_external_db_connections_on_account_id_and_name  (account_id,name) UNIQUE
#
class ExternalDbConnection < ApplicationRecord
  belongs_to :account
  has_many :external_db_queries, dependent: :destroy

  enum engine: { firebird: 0, mssql: 1 }
  # Tipo de ERP → determina la librería de consultas a sembrar (F6).
  enum erp_type: { generic: 0, sae: 1, microsip: 2, contpaq: 3 }, _prefix: :erp

  validates :name, presence: true, uniqueness: { scope: :account_id }
  validates :engine, presence: true
  validates :host, presence: true
  validates :port, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :database, presence: true

  scope :active, -> { where(active: true) }

  # Firebird: "host/port:/ruta.fdb" · SQL Server lo arma el adaptador con host/port/database.
  def firebird_dsn
    "#{host}/#{port}:#{database}"
  end

  # No filtra credenciales al serializar para el frontend.
  def push_event_data
    { id: id, name: name, engine: engine, host: host, active: active }
  end
end
