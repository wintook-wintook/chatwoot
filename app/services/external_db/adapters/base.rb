# frozen_string_literal: true

# @query_databases — interfaz común de los adaptadores de ERP (solo lectura).
class ExternalDb::Adapters::Base
  ConnectionError = Class.new(StandardError)

  def initialize(connection_record)
    @conn = connection_record
  end

  # Devuelve un string con la versión/identidad del servidor (para "probar conexión").
  def ping
    raise NotImplementedError
  end

  # Ejecuta un SELECT ya armado. `binds` = parámetros posicionales (solo Firebird).
  # Devuelve un Array de Hash con claves de columna (String).
  def select(_sql, _binds = [])
    raise NotImplementedError
  end

  # Renderiza un literal seguro para SQL inline (lo usa el adaptador sin bind nativo).
  def literal(_value, _type)
    raise NotImplementedError
  end

  # true si el adaptador hace binding por sustitución inline (MSSQL) en vez de `?`.
  def inline_binds?
    false
  end

  def close; end
end
