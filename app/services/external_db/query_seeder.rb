# frozen_string_literal: true

# @query_databases (F6) — crea las consultas de la librería para una conexión según su
# erp_type. Idempotente: no duplica las que ya existen (por nombre).
class ExternalDb::QuerySeeder
  def initialize(connection)
    @connection = connection
  end

  def seed!
    created = []
    ExternalDb::QueryLibrary.for_connection(@connection).each do |tpl|
      next if @connection.external_db_queries.exists?(name: tpl['name'])

      @connection.external_db_queries.create!(
        name: tpl['name'],
        description: tpl['description'],
        sql_template: tpl['sql_template'],
        params_schema: tpl['params_schema'],
        ai_enabled: tpl['ai_enabled']
      )
      created << tpl['name']
    end
    created
  end
end
