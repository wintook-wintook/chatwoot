# frozen_string_literal: true

# @query_databases — adaptador Firebird (SAE, Microsip, Contpaq-Firebird) vía gem `fb`.
# Usa bind params nativos (`?`), la forma más segura contra inyección.
#
# proyecto@erp_productos — CODIFICACIÓN: con charset NONE (el default de las conexiones)
# Firebird entrega los textos tal como los guardó el ERP, que en SAE y Microsip es la
# página de Windows (medido: "Precio p\xFAblico", "ca\xF1\xF3n"). Sin convertir, un nombre de
# producto con tilde llega como UTF-8 inválido y rompe la respuesta. Por eso, SOLO con
# charset NONE: los textos que no son UTF-8 válido se leen como Windows-1252, y los
# parámetros de texto se mandan en Windows-1252 para que "cañón" encuentre "cañón".
class ExternalDb::Adapters::Firebird < ExternalDb::Adapters::Base
  LEGACY_ENCODING = Encoding::Windows_1252

  def ping
    rows = connection.query(:hash, 'SELECT 1 AS OK FROM RDB$DATABASE')
    "Firebird OK (#{rows.size} fila de prueba)"
  end

  def select(sql, binds = [])
    return connection.query(:hash, sql, *binds) unless legacy_charset?

    connection.query(:hash, sql, *binds.map { |b| to_legacy(b) }).map { |row| row.transform_values { |v| from_legacy(v) } }
  end

  def close
    @connection&.close
  rescue StandardError => e
    Rails.logger.warn "[ExternalDb::Firebird] cierre: #{e.message}"
  ensure
    @connection = nil
  end

  private

  def legacy_charset?
    @conn.options['charset'].blank? || @conn.options['charset'].to_s.casecmp('NONE').zero?
  end

  def from_legacy(value)
    return value unless value.is_a?(String)
    return value.dup.force_encoding(Encoding::UTF_8) if value.dup.force_encoding(Encoding::UTF_8).valid_encoding?

    value.dup.force_encoding(LEGACY_ENCODING).encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
  end

  def to_legacy(value)
    return value unless value.is_a?(String) && !value.ascii_only?

    value.encode(LEGACY_ENCODING, invalid: :replace, undef: :replace)
  end

  def connection
    @connection ||= Fb::Database.new(
      database: @conn.firebird_dsn,
      username: @conn.username,
      password: @conn.password,
      charset: @conn.options['charset'].presence || 'NONE'
    ).connect
  rescue StandardError => e
    raise ConnectionError, e.message
  end
end
