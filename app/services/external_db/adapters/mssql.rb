# frozen_string_literal: true

# @query_databases — adaptador SQL Server (Contpaq) vía gem `tiny_tds` (~> 2.1).
# tiny_tds no tiene bind params nativos en `execute`: el QueryRunner sustituye los
# parámetros con literales tipados y escapados (#literal). Default TDS 7.0 porque los
# SQL Server de Contpaq son 2008 R2; configurable vía options['tds_version'].
class ExternalDb::Adapters::Mssql < ExternalDb::Adapters::Base
  def ping
    row = client.execute('SELECT @@VERSION AS v').each.first
    row ? row['v'].to_s.split("\n").first.strip : 'SQL Server OK'
  end

  def select(sql, _binds = [])
    client.execute(sql).each
  end

  def inline_binds?
    true
  end

  # Literal seguro para inyectar en el SQL (tiny_tds no tiene binds nativos).
  def literal(value, type)
    return 'NULL' if value.nil?

    case type.to_s
    when 'integer', 'number'
      value.to_s # ya viene coercionado a Integer/Float por el QueryRunner
    when 'date'
      "'#{value.strftime('%Y-%m-%d')}'"
    else
      "N'#{client.escape(value.to_s)}'"
    end
  end

  def close
    @client&.close
  rescue StandardError => e
    Rails.logger.warn "[ExternalDb::Mssql] cierre: #{e.message}"
  ensure
    @client = nil
  end

  private

  def client
    @client ||= TinyTds::Client.new(
      username: @conn.username,
      password: @conn.password,
      host: @conn.host,
      port: @conn.port,
      database: @conn.database,
      tds_version: @conn.options['tds_version'].presence || '7.0',
      use_utf16: false,
      login_timeout: 15,
      timeout: (@conn.options['timeout'] || 20).to_i
    )
  rescue StandardError => e
    raise ConnectionError, e.message
  end
end
