# frozen_string_literal: true

# @query_databases — adaptador Firebird (SAE, Microsip, Contpaq-Firebird) vía gem `fb`.
# Usa bind params nativos (`?`), la forma más segura contra inyección.
class ExternalDb::Adapters::Firebird < ExternalDb::Adapters::Base
  def ping
    rows = connection.query(:hash, 'SELECT 1 AS OK FROM RDB$DATABASE')
    "Firebird OK (#{rows.size} fila de prueba)"
  end

  def select(sql, binds = [])
    connection.query(:hash, sql, *binds)
  end

  def close
    @connection&.close
  rescue StandardError => e
    Rails.logger.warn "[ExternalDb::Firebird] cierre: #{e.message}"
  ensure
    @connection = nil
  end

  private

  def connection
    @connection ||= Fb::Database.new(
      database: @conn.firebird_dsn,
      username: @conn.username,
      password: @conn.password,
      charset: @conn.options['charset'] || 'NONE'
    ).connect
  rescue StandardError => e
    raise ConnectionError, e.message
  end
end
