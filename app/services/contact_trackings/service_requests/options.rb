# frozen_string_literal: true

# ================================================================================
# proyecto@solicitudes — LAS OPCIONES DE @solicitudes(...) (27/11/2026)
# ================================================================================
# Antes la directiva solo entendía «asignar=campo» (y el patrón se rompía si venía otra cosa).
# Ahora acepta varias, separadas por coma. Todas son OPCIONALES: sin ellas, @solicitudes hace
# exactamente lo de siempre (regla del plan docs/solicitudes_datos_fechas_plan.md: no cambiar a
# los agentes que ya existen).
#
#   @solicitudes(asignar=unidad, datos=primero, sin_dato=pendiente, fecha=mes/dia, faltan=2)
#
#   asignar=campo        el campo del tipo de caso que recibe la unidad apartada (ya existía)
#   datos=primero        no ofrece horarios mientras falte un dato obligatorio del caso
#   sin_dato=pendiente   «no sé el peso»: ese dato queda como pendiente y ya no se vuelve a pedir
#   fecha=mes/dia        11/04/2026 es 4 de noviembre (clientes que escriben como en EE. UU.)
#   faltan=N             pide como máximo N datos por mensaje
# ================================================================================

class ContactTrackings::ServiceRequests::Options
  DIRECTIVE_RE = /@solicitudes\b(?:\s*\(([^)]*)\))?/i

  attr_reader :assign, :max_missing

  def self.parse(text)
    new(text.to_s[DIRECTIVE_RE, 1])
  end

  def initialize(inner)
    pares = pairs(inner)
    @assign = pares['asignar'].presence
    @data_first = fold(pares['datos']) == 'primero'
    @unknown_pending = fold(pares['sin_dato']) == 'pendiente'
    @month_first = fold(pares['fecha']).delete(' ').in?(%w[mes/dia mm/dd])
    @max_missing = pares['faltan'].to_s[/\A\d+\z/]&.to_i&.nonzero?
  end

  def data_first? = @data_first
  def unknown_pending? = @unknown_pending
  def month_first? = @month_first

  private

  def pairs(inner)
    inner.to_s.split(',').filter_map do |par|
      clave, valor = par.split('=', 2).map { |parte| parte.to_s.strip }
      [fold(clave), valor.to_s] if clave.present?
    end.to_h
  end

  def fold(text)
    I18n.transliterate(text.to_s).downcase.strip
  end
end
