# frozen_string_literal: true

# @query_databases — construye el adaptador correcto según el motor de la conexión.
module ExternalDb::AdapterFactory
  module_function

  def build(connection_record)
    case connection_record.engine.to_s
    when 'firebird' then ExternalDb::Adapters::Firebird.new(connection_record)
    when 'mssql'    then ExternalDb::Adapters::Mssql.new(connection_record)
    else
      raise ArgumentError, "motor no soportado: #{connection_record.engine}"
    end
  end
end
