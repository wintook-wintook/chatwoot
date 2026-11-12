# frozen_string_literal: true

# ================================================================================
# feat/ficha_agente_ia — CUÁNDO SE LEVANTA UN TICKET
# ================================================================================
# Pedido del usuario (10/11/2026): «faltan las reglas de por qué se debe levantar un
# ticket… deben existir algunos motivos». En la ficha, cada tipo de ticket marcado dice:
#   reasons   los motivos, en palabras del cliente («quiere hablar con una persona»,
#             «reporta una falla») → la descripción de su ruta (lo que mira el
#             clasificador) y su alcance
#   priority  baja | media | alta | urgente → @crear_ticket(tipo=X, prioridad=alta)
#   escalate_from  rutas de fuente que, si no encuentran la respuesta, levantan este ticket
#             («@ruta(…): {{hoja:…}} -> @crear_ticket(tipo=X)»: la escalada que el motor ya entiende)
# ================================================================================

module ContactTrackings::Ficha::TicketUse
  PRIORITIES = %w[baja media alta urgente].freeze
  MAX_REASONS = 8
  MAX_REASON = 80

  module_function

  def clean(config)
    h = config.to_h.stringify_keys
    prioridad = PRIORITIES.include?(h['priority'].to_s) ? h['priority'].to_s : nil
    # escalate_from: llaves de oferta (o nombres de ruta) que, si no encuentran, levantan este ticket.
    desde = Array(h['escalate_from']).map(&:to_s).compact_blank.uniq
    { 'reasons' => reasons(h['reasons']).presence, 'priority' => prioridad, 'escalate_from' => desde.presence }.compact.presence
  end

  def reasons(lista)
    Array(lista).map { |m| m.to_s.tr('(),', '   ').squish.first(MAX_REASON) }.compact_blank.uniq.first(MAX_REASONS)
  end

  ESCALABLE = %w[sheet doc articles canned forum contpaq discourse erp].freeze

  # Marca en cada oferta de fuente la escalada del ticket que la pidió (Offers#target).
  def escalate!(ofertas)
    fuentes = ofertas.select { |o| ESCALABLE.include?(o[:kind]) }.index_by { |o| o[:key].to_s }
    ofertas.select { |o| o[:kind] == 'case_type' }.each do |ticket|
      Array(ticket[:escalate_from]).filter_map { |key| fuentes[key.to_s] }
                                   .each { |fuente| fuente[:escalation] ||= ticket[:directive] }
    end
  end

  def directive(nombre, config)
    prioridad = config && config['priority']
    prioridad ? "@crear_ticket(tipo=#{nombre}, prioridad=#{prioridad})" : "@crear_ticket(tipo=#{nombre})"
  end
end
