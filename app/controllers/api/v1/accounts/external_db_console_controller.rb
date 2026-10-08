# frozen_string_literal: true

# @query_databases — consola "conversar con la BD". Accesible al AGENTE (no solo admin):
# ejecuta una consulta predefinida con parámetros. La definición de consultas/conexiones
# sigue siendo solo-admin (otros controllers); aquí solo se EJECUTA lo ya permitido.
class Api::V1::Accounts::ExternalDbConsoleController < Api::V1::Accounts::BaseController
  # Catálogo para la consola del agente: conexiones activas + sus consultas activas
  # (metadatos, sin credenciales). Accesible al agente (no solo admin).
  def catalog
    connections = Current.account.external_db_connections.active.order(:name)
    render json: connections.map { |conn| catalog_connection_json(conn) }
  end

  # Modo B (preview): pregunta en lenguaje natural → la IA elige la consulta ai_enabled,
  # la corre y redacta la respuesta. Mismo motor que usará el bot en el chat.
  def ask
    connection = Current.account.external_db_connections.active.find(params[:connection_id])
    result = ExternalDb::AiQueryService.new(connection, params[:question].to_s).perform
    render json: {
      answer: result.answer,
      query_name: result.query_name,
      params: result.params,
      rows: result.rows,
      row_count: result.rows.size
    }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # Modo A de la consola: ejecutar una consulta predefinida (allowlist) con params.
  def run
    query = Current.account.external_db_queries.active.find(params[:query_id])
    result = ExternalDb::QueryRunner.new(query, query_params).perform
    render json: result_json(query, result)
  rescue ExternalDb::QueryRunner::ParamError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.warn "[ExternalDbConsole] error ejecutando consulta: #{e.class}"
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # proyecto@erp_productos — "Probar como el agente": el mensaje de un cliente → la IA llena
  # los parámetros que el agente pediría con "?" → la consulta, igual que en el chat
  # (AskedParams + AskedRun). Por defecto se piden los parámetros de búsqueda (texto,
  # números, sí/no); `asked` permite elegirlos.
  def try_asked
    query = Current.account.external_db_queries.active.find(params[:query_id])
    filled = ExternalDb::AskedParams.new(query: query, asked: asked_keys(query), question: params[:message].to_s).call
    return render json: { error: 'La IA no respondió (revisa la integración de OpenAI).' }, status: :unprocessable_entity unless filled
    return render json: { use: false, params: {} } unless filled[:use]

    render json: asked_json(filled[:params], ExternalDb::AskedRun.new(query, filled[:params]).call)
  rescue ExternalDb::QueryRunner::ParamError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  ASKABLE_TYPES = %w[words number boolean].freeze

  def asked_keys(query)
    requested = Array(params[:asked]).map(&:to_s).compact_blank
    return requested if requested.any?

    Array(query.params_schema).select { |p| ASKABLE_TYPES.include?(p['type']) }.pluck('key')
  end

  def asked_json(filled, data)
    { use: true, params: filled, partial: data[:partial], columns: data[:columns], rows: data[:rows],
      row_count: data[:rows].size }
  end

  def catalog_connection_json(conn)
    {
      id: conn.id,
      name: conn.name,
      engine: conn.engine,
      erp_type: conn.erp_type,
      queries: conn.external_db_queries.active.order(:name).map do |q|
        { id: q.id, name: q.name, description: q.description, params_schema: q.params_schema }
      end
    }
  end

  def query_params
    params[:params]&.to_unsafe_h || {}
  end

  def result_json(query, result)
    {
      columns: result.columns,
      rows: result.rows,
      row_count: result.row_count,
      duration_ms: result.duration_ms,
      query: { id: query.id, name: query.name, sql_preview: query.sql_template }
    }
  end
end
