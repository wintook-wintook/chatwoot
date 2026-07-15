# frozen_string_literal: true

# @query_databases — CRUD de consultas predefinidas (solo admin), anidadas a una conexión.
class Api::V1::Accounts::ExternalDbQueriesController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :fetch_connection
  before_action :fetch_query, only: [:show, :update, :destroy]

  def index
    render json: @connection.external_db_queries.order(:name).map { |q| query_json(q) }
  end

  def show
    render json: query_json(@query)
  end

  def create
    @query = @connection.external_db_queries.new(query_params)
    @query.save!
    render json: query_json(@query), status: :created
  end

  def update
    @query.update!(query_params)
    render json: query_json(@query)
  end

  def destroy
    @query.destroy!
    head :ok
  end

  private

  def fetch_connection
    @connection = Current.account.external_db_connections.find(params[:external_db_connection_id])
  end

  def fetch_query
    @query = @connection.external_db_queries.find(params[:id])
  end

  def query_params
    params.require(:external_db_query)
          .permit(:name, :description, :sql_template, :row_limit, :ai_enabled,
                  :result_format, :active, params_schema: [:key, :label, :type, :required])
  end

  def query_json(query)
    {
      id: query.id,
      external_db_connection_id: query.external_db_connection_id,
      name: query.name,
      description: query.description,
      sql_template: query.sql_template,
      params_schema: query.params_schema,
      row_limit: query.row_limit,
      ai_enabled: query.ai_enabled,
      result_format: query.result_format,
      active: query.active
    }
  end
end
