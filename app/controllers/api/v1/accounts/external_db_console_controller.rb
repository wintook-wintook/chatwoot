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

  private

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
