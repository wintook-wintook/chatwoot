# frozen_string_literal: true

# @query_databases — CRUD de conexiones a BDs de ERPs (solo admin).
# La contraseña se acepta al crear/editar pero NUNCA se devuelve en el JSON.
class Api::V1::Accounts::ExternalDbConnectionsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :fetch_connection, only: [:show, :update, :destroy, :test_connection]

  def index
    @connections = Current.account.external_db_connections.order(:name)
    render json: @connections.map { |c| connection_json(c) }
  end

  def show
    render json: connection_json(@connection)
  end

  def create
    @connection = Current.account.external_db_connections.new(connection_params)
    @connection.save!
    render json: connection_json(@connection), status: :created
  end

  def update
    # password en blanco = conservar la actual (no sobreescribir con vacío).
    attrs = connection_params.to_h
    attrs.delete('password') if attrs['password'].blank?
    @connection.update!(attrs)
    render json: connection_json(@connection)
  end

  def destroy
    @connection.destroy!
    head :ok
  end

  # Ping read-only al ERP (no guarda nada). Errores del driver → JSON, no 500.
  def test_connection
    info = ExternalDb::AdapterFactory.build(@connection).ping
    render json: { ok: true, info: info }
  rescue StandardError => e
    render json: { ok: false, error: e.message }, status: :ok
  end

  private

  def fetch_connection
    @connection = Current.account.external_db_connections.find(params[:id])
  end

  def connection_params
    params.require(:external_db_connection)
          .permit(:name, :engine, :host, :port, :database, :username, :password,
                  :read_only, :active, options: {})
  end

  # Sin password. `has_password` indica si hay credencial guardada (para la UI).
  def connection_json(conn)
    {
      id: conn.id,
      name: conn.name,
      engine: conn.engine,
      host: conn.host,
      port: conn.port,
      database: conn.database,
      username: conn.username,
      has_password: conn.password.present?,
      options: conn.options,
      read_only: conn.read_only,
      active: conn.active,
      queries_count: conn.external_db_queries.count
    }
  end
end
