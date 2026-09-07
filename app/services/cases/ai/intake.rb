# frozen_string_literal: true

# ================================================================================
# @tickets_cases — Intake IA de tickets (directiva @crear_ticket inteligente)
# ================================================================================
# Servicio: Cases::Ai::Intake
#
# A diferencia de Cases::Ai::Classifier (que solo clasifica un título ya dado),
# el Intake LEE LA CONVERSACIÓN y devuelve el ticket YA ARMADO:
#   title · description(resumen) · ticket_kind · impact · urgency
#   · case_type_id · affected_service_id · category_id
#   · churn_risk · missing_info[] · confidence · reasoning
#
# Elige tipo/servicio/categoría de las listas REALES de la cuenta (por id) para
# que el resultado sea aplicable; nunca inventa ids. Recibe además la "política"
# del prompt complementario (reglas de negocio en lenguaje natural) para que el
# usuario gobierne cómo se arma el ticket.
#
# Devuelve un Hash saneado o nil ante cualquier fallo (el caller degrada).
# Ver: docs/vault-tickets/implementacion/Plan-Crear-Ticket-IA.md
# ================================================================================

class Cases::Ai::Intake < Cases::Ai::BaseService
  KINDS     = CaseTicket.ticket_kinds.keys.freeze
  IMPACTS   = CaseTicket.impacts.keys.freeze
  URGENCIES = CaseTicket.urgencies.keys.freeze

  # conversation_text: transcripción reciente (Cliente/Bot: ...).
  # policy:            prompt complementario sin las directivas técnicas.
  def extract(conversation_text:, policy: nil)
    types      = @account.case_types.order(:position).pluck(:id, :name)
    services   = @account.case_services.where(active: true).pluck(:id, :name)
    categories = @account.case_categories.where(active: true).pluck(:id, :name)

    raw = chat(
      system: system_prompt(policy),
      user: user_prompt(conversation_text, types, services, categories),
      json: true,
      max_tokens: 600
    )
    return nil if raw.blank?

    sanitize(raw, types, services, categories)
  end

  private

  def system_prompt(policy)
    base = <<~PROMPT.strip
      Eres un agente de soporte que registra tickets siguiendo ITIL 4. A partir de
      una conversación con un cliente, decides si amerita un ticket y, de ser así,
      lo redactas y clasificas. Responde EXCLUSIVAMENTE con un objeto JSON con estas claves:
        - "ticket_worthy": true SOLO si la conversación contiene una solicitud, un problema,
          una queja o una intención concreta que amerite abrir un ticket para una persona.
          false para saludos, charla trivial, agradecimientos, o temas ya resueltos/atendidos
          (por ejemplo, una cita que ya se agendó). Ante la duda, false.
          IMPORTANTE: evaluá la CONVERSACIÓN COMPLETA, no solo el último mensaje. Si en algún punto
          anterior el cliente ya planteó una solicitud concreta y los mensajes siguientes son él
          dando más datos, confirmando algo, o preguntando por el estado — es la MISMA solicitud
          en curso: seguí devolviendo true, no la reevalúes como si el último mensaje fuera
          charla trivial aislada.
        - "multiple_requests": true SOLO si el cliente describe DOS O MÁS servicios/solicitudes
          CLARAMENTE INDEPENDIENTES entre sí (distintos trabajos, cada uno con su propio
          origen/destino/fecha/alcance, que no tiene sentido resolver como un solo ticket). false
          en cualquier otro caso — incluido un solo trabajo que necesita varios recursos/unidades
          a la vez (eso SIGUE siendo una sola solicitud). Ante la duda, false.
        - "requests_summary": SOLO si "multiple_requests" es true, un arreglo con un resumen breve
          (una línea cada uno) de CADA solicitud detectada, en el orden en que aparecen, sin omitir
          ninguna — esto es lo único que va a leer la persona que las separe, así que no puede
          faltar información de ninguna solicitud. Vacío si "multiple_requests" es false.
        - "resources_requested": SOLO si "multiple_requests" es false y el cliente nombra UNO O
          MÁS recursos/unidades CONCRETOS que hacen falta para EL MISMO trabajo — cada uno
          identificable por su propio nombre, modelo, código o característica que lo distingue de
          un recurso genérico (no importa el rubro: puede ser una unidad de un vehículo, un equipo,
          una persona con un rol específico, etc.). Aplica también con UN SOLO recurso, siempre que
          sea concreto (ej. "HIAB con capacidad de 12 toneladas" cuenta; "una grúa" o "un camión"
          sola, sin más detalle, no). Un arreglo con la descripción tal cual la dio el cliente de
          CADA recurso, uno por elemento, en el orden en que aparecen.
          NO lo llenes solo por una cantidad genérica ("2 unidades", "3 personas", "una grúa") si el
          cliente no distinguió cuál es cuál/qué tipo — en ese caso el pedido sigue siendo UNA sola
          solicitud normal, dejá el arreglo vacío. Vacío también si "multiple_requests" es true.
        - "needs_escalation": true SOLO si, según las REGLAS DEL NEGOCIO de más abajo (cuando las
          haya), esta solicitud NO se debe resolver de forma automática y tiene que pasar
          directamente a un asesor humano — por ejemplo, pide algo que esas reglas marcan como
          fuera de alcance de esta versión, o falta información técnica crítica que esas reglas
          dicen que no se puede completar sola. Es independiente de "ticket_worthy": puede ser
          true aunque el caso sí amerite ticket (el ticket se crea igual, pero se avisa que un
          humano debe tomarlo desde ya). Si no hay reglas de negocio que apliquen, o ninguna dice
          que esto deba escalar, false. Ante la duda, false — no escales por cualquier cosa.
        - "escalation_reason": SOLO si "needs_escalation" es true, una frase breve en español
          explicando por qué (para que el asesor entienda sin releer todo). Vacío si no aplica.
        - "pending_technical_question": true SOLO si, junto con la solicitud, el cliente hizo
          una pregunta técnica concreta (sobre el servicio, una unidad, un requisito, un precio,
          etc.) que TODAVÍA no fue respondida en ningún mensaje posterior del bot en esta misma
          conversación. false si no hizo ninguna pregunta, o si ya fue respondida. Ante la duda,
          false — no marques como pendiente algo que ya se contestó.
        - "technical_question": SOLO si "pending_technical_question" es true, el texto de la
          pregunta tal cual la hizo el cliente. Vacío si no aplica.
        - "title": título claro y breve del problema (NO copies el mensaje literal).
        - "description": resumen de 2 a 4 líneas: qué pasa, desde cuándo y qué intentó el cliente.
        - "ticket_kind": uno de [#{KINDS.join(', ')}].
        - "impact": uno de [#{IMPACTS.join(', ')}].
        - "urgency": uno de [#{URGENCIES.join(', ')}].
        - "case_type_id": el id del TIPO de caso de la lista dada, o null.
        - "affected_service_id": el id del servicio afectado de la lista dada, o null.
        - "category_id": el id de la categoría de la lista dada, o null.
        - "churn_risk": true si el cliente muestra enojo fuerte o amenaza con irse/cancelar; si no, false.
        - "missing_info": arreglo de datos clave que faltan para atender el caso (p.ej. ["número de cliente"]); vacío si no falta nada.
        - "confidence": número entre 0 y 1.
        - "reasoning": una frase breve en español.
      No inventes ids: usa solo los de las listas. Si ninguno aplica, usa null.
      Redacta title y description en español, en tercera persona, sin saludos.
    PROMPT
    return base if policy.blank?

    "#{base}\n\nREGLAS DEL NEGOCIO (respétalas al armar el ticket):\n#{policy.strip}"
  end

  def user_prompt(conversation_text, types, services, categories)
    <<~PROMPT.strip
      CONVERSACIÓN:
      #{conversation_text.presence || '(sin contexto)'}

      TIPOS DE CASO DISPONIBLES (id: nombre):
      #{listing(types)}

      SERVICIOS DISPONIBLES (id: nombre):
      #{listing(services)}

      CATEGORÍAS DISPONIBLES (id: nombre):
      #{listing(categories)}
    PROMPT
  end

  def listing(pairs)
    return '(ninguno)' if pairs.blank?

    pairs.map { |id, name| "#{id}: #{name}" }.join("\n")
  end

  # Mantiene solo valores válidos; descarta enums fuera de rango e ids inexistentes.
  def sanitize(raw, types, services, categories)
    type_ids     = types.map(&:first)
    service_ids  = services.map(&:first)
    category_ids = categories.map(&:first)

    {
      'ticket_worthy' => ActiveModel::Type::Boolean.new.cast(raw.fetch('ticket_worthy', true)),
      'multiple_requests' => ActiveModel::Type::Boolean.new.cast(raw['multiple_requests']) || false,
      'requests_summary' => Array(raw['requests_summary']).map { |s| s.to_s.strip }.reject(&:blank?).first(10),
      'resources_requested' => Array(raw['resources_requested']).map { |s| s.to_s.strip }.reject(&:blank?).first(10),
      'needs_escalation' => ActiveModel::Type::Boolean.new.cast(raw['needs_escalation']) || false,
      'escalation_reason' => raw['escalation_reason'].to_s.strip[0, 280].presence,
      'pending_technical_question' => ActiveModel::Type::Boolean.new.cast(raw['pending_technical_question']) || false,
      'technical_question' => raw['technical_question'].to_s.strip[0, 280].presence,
      'title' => raw['title'].to_s.strip.presence,
      'description' => raw['description'].to_s.strip.presence,
      'ticket_kind' => KINDS.include?(raw['ticket_kind']) ? raw['ticket_kind'] : nil,
      'impact' => IMPACTS.include?(raw['impact']) ? raw['impact'] : nil,
      'urgency' => URGENCIES.include?(raw['urgency']) ? raw['urgency'] : nil,
      'case_type_id' => type_ids.include?(raw['case_type_id']) ? raw['case_type_id'] : nil,
      'affected_service_id' => service_ids.include?(raw['affected_service_id']) ? raw['affected_service_id'] : nil,
      'category_id' => category_ids.include?(raw['category_id']) ? raw['category_id'] : nil,
      'churn_risk' => ActiveModel::Type::Boolean.new.cast(raw['churn_risk']) || false,
      'missing_info' => Array(raw['missing_info']).map { |s| s.to_s.strip }.reject(&:blank?).first(5),
      'confidence' => raw['confidence'].to_f.clamp(0.0, 1.0),
      'reasoning' => raw['reasoning'].to_s[0, 280]
    }
  end
end
