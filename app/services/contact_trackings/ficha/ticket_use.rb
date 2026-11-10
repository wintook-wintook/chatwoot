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
# ================================================================================

module ContactTrackings::Ficha::TicketUse
  PRIORITIES = %w[baja media alta urgente].freeze
  MAX_REASONS = 8
  MAX_REASON = 80

  module_function

  def clean(config)
    h = config.to_h.stringify_keys
    motivos = Array(h['reasons']).map { |m| m.to_s.tr('(),', '   ').squish.first(MAX_REASON) }.compact_blank.uniq.first(MAX_REASONS)
    prioridad = PRIORITIES.include?(h['priority'].to_s) ? h['priority'].to_s : nil
    resultado = { 'reasons' => motivos.presence, 'priority' => prioridad }.compact
    resultado.presence
  end

  def directive(nombre, config)
    prioridad = config && config['priority']
    prioridad ? "@crear_ticket(tipo=#{nombre}, prioridad=#{prioridad})" : "@crear_ticket(tipo=#{nombre})"
  end
end
