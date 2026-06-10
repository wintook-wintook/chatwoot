# frozen_string_literal: true

# ================================================================================
# @tickets_cases 3B — Clasificación automática
# ================================================================================
# Servicio: Cases::Ai::Classifier
#
# Clasifica un CaseTicket según ITIL a partir de su título + descripción:
#   ticket_kind · impact · urgency · affected_service_id · category_id
# Elige el servicio/categoría de las listas reales de la cuenta (por id) para que
# el resultado sea aplicable. Devuelve un Hash saneado (solo valores válidos) con
# `confidence` y `reasoning`, o nil ante cualquier fallo.
# ================================================================================

class Cases::Ai::Classifier < Cases::Ai::BaseService
  KINDS    = CaseTicket.ticket_kinds.keys.freeze     # incident/service_request/problem/change/query
  IMPACTS  = CaseTicket.impacts.keys.freeze          # low/medium/high
  URGENCIES = CaseTicket.urgencies.keys.freeze

  def classify(ticket)
    services   = @account.case_services.where(active: true).pluck(:id, :name)
    categories = @account.case_categories.where(active: true).pluck(:id, :name)

    raw = chat(
      system: system_prompt,
      user:   user_prompt(ticket, services, categories),
      json:   true,
      max_tokens: 400
    )
    return nil if raw.blank?

    sanitize(raw, services, categories)
  end

  private

  def system_prompt
    <<~PROMPT.strip
      Eres un clasificador de tickets de soporte siguiendo ITIL 4. A partir del título
      y la descripción de un ticket, determina su clasificación. Responde EXCLUSIVAMENTE
      con un objeto JSON con estas claves:
        - "ticket_kind": uno de [#{KINDS.join(', ')}]
        - "impact": uno de [#{IMPACTS.join(', ')}]
        - "urgency": uno de [#{URGENCIES.join(', ')}]
        - "affected_service_id": el id del servicio afectado de la lista dada, o null
        - "category_id": el id de la categoría de la lista dada, o null
        - "confidence": número entre 0 y 1 (qué tan seguro estás)
        - "reasoning": una frase breve en español explicando la clasificación
      No inventes ids: usa solo los de las listas. Si ninguno aplica, usa null.
    PROMPT
  end

  def user_prompt(ticket, services, categories)
    <<~PROMPT.strip
      TÍTULO: #{ticket.title}
      DESCRIPCIÓN: #{ticket.description.presence || '(sin descripción)'}

      SERVICIOS DISPONIBLES (id: nombre):
      #{services.map { |id, name| "#{id}: #{name}" }.join("\n")}

      CATEGORÍAS DISPONIBLES (id: nombre):
      #{categories.map { |id, name| "#{id}: #{name}" }.join("\n")}
    PROMPT
  end

  # Mantiene solo valores válidos; descarta enums fuera de rango e ids inexistentes.
  def sanitize(raw, services, categories)
    service_ids  = services.map(&:first)
    category_ids = categories.map(&:first)

    {
      'ticket_kind'         => KINDS.include?(raw['ticket_kind']) ? raw['ticket_kind'] : nil,
      'impact'              => IMPACTS.include?(raw['impact']) ? raw['impact'] : nil,
      'urgency'             => URGENCIES.include?(raw['urgency']) ? raw['urgency'] : nil,
      'affected_service_id' => service_ids.include?(raw['affected_service_id']) ? raw['affected_service_id'] : nil,
      'category_id'         => category_ids.include?(raw['category_id']) ? raw['category_id'] : nil,
      'confidence'          => raw['confidence'].to_f.clamp(0.0, 1.0),
      'reasoning'           => raw['reasoning'].to_s[0, 280]
    }
  end
end
