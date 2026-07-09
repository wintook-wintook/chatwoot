# frozen_string_literal: true

# ================================================================================
# @tickets_cases 3E — Resumen + causa raíz sugerida
# ================================================================================
# Servicio: Cases::Ai::Summarizer
#
# A partir del ticket (título, descripción, clasificación) y su historial de
# eventos (transiciones con notas), genera un resumen del caso, una causa raíz
# sugerida y una solución sugerida. Alimenta el cierre documentado (2G) y la
# generación de artículos (2H). Devuelve un Hash o nil ante fallo.
# ================================================================================

class Cases::Ai::Summarizer < Cases::Ai::BaseService
  def summarize(ticket)
    raw = chat(
      system: system_prompt,
      user:   user_prompt(ticket),
      json:   true,
      max_tokens: 600
    )
    return nil if raw.blank?

    {
      'summary'            => raw['summary'].to_s.strip,
      'root_cause'         => raw['root_cause'].to_s.strip,
      'suggested_solution' => raw['suggested_solution'].to_s.strip
    }
  end

  private

  def system_prompt
    <<~PROMPT.strip
      Eres un analista de soporte técnico. A partir de los datos y el historial de un
      ticket, responde EXCLUSIVAMENTE con un objeto JSON con estas claves (en español):
        - "summary": resumen breve del caso (2-4 frases)
        - "root_cause": la causa raíz más probable del problema
        - "suggested_solution": la solución aplicada o recomendada
      Sé concreto y basa todo en la información dada. No inventes datos que no estén.
    PROMPT
  end

  def user_prompt(ticket)
    <<~PROMPT.strip
      TÍTULO: #{ticket.title}
      DESCRIPCIÓN: #{ticket.description.presence || '(sin descripción)'}
      TIPO ITIL: #{ticket.ticket_kind}
      PRIORIDAD: #{ticket.priority}

      HISTORIAL (estado y notas):
      #{timeline(ticket)}
    PROMPT
  end

  # Transiciones con su nota (reason) + notas internas, en orden cronológico.
  def timeline(ticket)
    lines = ticket.case_events.order(:created_at).filter_map do |e|
      p = e.payload || {}
      if p['from'] && p['to']
        note = p['reason'].present? ? " — #{p['reason']}" : ''
        "#{p['from']} → #{p['to']}#{note}"
      elsif e.event_type == 'internal_note' && p['content'].present?
        "Nota interna: #{p['content']}"
      end
    end
    lines.presence&.join("\n") || '(sin eventos)'
  end
end
