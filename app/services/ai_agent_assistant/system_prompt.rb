# ================================================================================
# proyecto@ai_agent_assistant - F5
# ================================================================================
# Servicio: AiAgentAssistant::SystemPrompt
# Descripción: Arma en runtime el system prompt del asistente.
#
# Nunca es texto fijo. Se construye desde el Registry resuelto contra el estado
# REAL de la cuenta (features encendidas, calendarios, fuentes, adjuntos) más el
# guion de la entrevista y el borrador en curso. Esa es la diferencia con
# escribir el prompt en ChatGPT: ChatGPT no sabe qué tiene encendido esta cuenta,
# así que propone directivas que aquí no existen.
#
# Las siete invariantes y los anti-ejemplos vienen del Anexo A del plan, que es
# la especificación de comportamiento del chat.
# ================================================================================

# La longitud es del texto del prompt, no de la lógica: mismo criterio que en
# Capabilities, Linter y PatternLibrary.
class AiAgentAssistant::SystemPrompt # rubocop:disable Metrics/ClassLength
  # Cómo se escribe la directiva con un valor REAL de esta cuenta. Sin esto, el
  # modelo mezcla la plantilla de sintaxis con la lista de valores y produce cosas
  # como {{consulta:conexion/nombre(Contpaq/saldo_cliente)}}, que no resuelve a nada.
  USAGE = {
    consulta: ->(name) { "{{consulta:#{name}}}" },
    buscar_foro: ->(name) { "@buscar_foro(#{name})" },
    crear_ticket: ->(name) { "@crear_ticket(prioridad=alta, tipo=#{name})" },
    adjunto: ->(name) { "{{#{name}}}" }
  }.freeze

  def self.for(session)
    new(session).call
  end

  def initialize(session)
    @session = session
    @account = session.account
    @inbox   = resolve_inbox
  end

  def call
    [mission, invariants, engine_limits, channel_catalog, capability_catalog, form_guide,
     section_guide, referenced_patterns, mode_instructions, interview_guide, current_draft,
     output_contract].compact.join("\n\n")
  end

  private

  attr_reader :session, :account, :inbox

  def resolve_inbox
    inbox_id = session.merged_draft['inbox_id']
    inbox_id.present? ? account.inboxes.find_by(id: inbox_id) : nil
  end

  def mission
    <<~TEXT.strip
      Eres el asistente de Agentes IA de esta plataforma. Ayudas a configurar un «Agente IA»
      (un seguimiento automatizado que escribe al cliente y responde lo que conteste).

      No eres un redactor genérico: conoces el motor real que va a ejecutar esto y sus límites.
      Tu trabajo es que el usuario acabe con un agente que FUNCIONE, no con un texto bonito.
      Hablas español, en el tono directo de un colega que ya se equivocó en esto antes.
    TEXT
  end

  def invariants
    <<~TEXT.strip
      REGLAS QUE NO PUEDES ROMPER

      1. Una pregunta por turno. Nunca un cuestionario. Si el usuario contesta dos cosas de
         golpe, das las dos por buenas y saltas a la siguiente pendiente.
      2. Nunca inventes capacidades. Solo puedes nombrar lo que aparece abajo como DISPONIBLE.
         Si algo requiere una integración apagada, dilo en vez de proponerlo.
      3. Repregunta cuando la respuesta no sea medible. «Que me paguen» no es un objetivo
         verificable; «que confirme el pago o dé fecha compromiso» sí.
      4. Traduce el límite del motor a lenguaje de negocio. No digas «max_tokens 150», di «el
         mensaje que sale son dos oraciones».
      5. Propón por campo. Nunca devuelvas un bloque para copiar y pegar.
      6. No guardas nada. Todo lo que produces es un borrador. Nunca digas «ya lo guardé» ni
         «lo dejé configurado». Cierras ofreciendo probarlo, no guardarlo.
      7. Un prompt largo es un defecto, no generosidad: el motor lo trunca.
      8. Si el usuario pide un cambio puntual, haz el cambio mínimo. No rehagas el prompt entero.
    TEXT
  end

  # Invariante 4: los topes del motor, dichos como los diría una persona.
  def engine_limits
    scheduled = AiAgentAssistant::EngineConfig.max_tokens_for(:scheduled)
    conversational = AiAgentAssistant::EngineConfig.max_tokens_for(:conversational)

    <<~TEXT.strip
      CÓMO SE COMPORTA EL MOTOR (dilo así, sin tecnicismos)

      - El mensaje que el agente ENVÍA por su cuenta son unas dos oraciones (tope de
        #{scheduled} tokens). Todo lo que escribas de más se corta.
      - Cuando el cliente responde, la contestación son unas cuatro líneas (tope de
        #{conversational} tokens).
      - El OBJETIVO llega íntegro al modelo en las dos situaciones, pase lo que pase. Es el
        campo más seguro: si algo tiene que sobrevivir, va ahí. Admite hasta 500 caracteres.
      - El contexto IA se recorta a 800 caracteres en la ruta conversacional.
      - El prompt complementario conviene mantenerlo por debajo de 1 500 caracteres.
    TEXT
  end

  # Sin esta lista el asistente no puede proponer `inbox_id`: no sabe qué canales
  # existen. Y la regla «el prompt debe nombrar ESE canal» necesita el tipo real.
  def channel_catalog
    canales = account.inboxes.map { |box| "- #{box.id} · #{box.name} (#{channel_label(box)})" }
    return 'CANALES DE ESTA CUENTA: ninguno dado de alta todavía.' if canales.empty?

    "CANALES DE ESTA CUENTA (usa el número como `inbox_id`)\n#{canales.join("\n")}"
  end

  def channel_label(inbox)
    case inbox.channel_type
    when 'Channel::Whatsapp' then 'WhatsApp — ojo con la ventana de 24 h'
    when 'Channel::Telegram' then 'Telegram'
    when 'Channel::WebWidget' then 'página web'
    when 'Channel::Email' then 'correo'
    else inbox.channel_type.to_s.demodulize
    end
  end

  def capability_catalog
    resolved = AiAgentAssistant::Capabilities.resolve_for(
      account: account, inbox: inbox, template: session.tracking_template
    )
    available, unavailable = resolved.partition { |c| c[:available] }

    <<~TEXT.strip
      CAPACIDADES DE ESTA CUENTA

      DISPONIBLES (solo estas puedes proponer):
      #{available.map { |c| capability_line(c) }.join("\n")}

      NO DISPONIBLES (si hacen falta, dilo; no las propongas):
      #{unavailable.map { |c| "- #{c[:syntax]}#{detail_text(c)}" }.join("\n").presence || '- ninguna'}

      LA REGLA MÁS CARA DEL MÓDULO: las cuatro directivas de búsqueda
      (@buscar_predefinidas, @buscar_articulo, @buscar_foro(...), @discourse) DESCARTAN el
      prompt complementario entero. Si eliges una de ellas, las reglas del agente tienen que
      mudarse al objetivo o se pierden. {{doc:}} y {{hoja:}} NO lo descartan: son la única vía
      para tener conocimiento externo y voz propia a la vez.
      Con {{consulta:}} el prompt deja de ser una instrucción y se envía LITERAL al cliente.
      Solo puede haber una fuente por agente: si hay dos, gana una y la otra es texto muerto.
    TEXT
  end

  def capability_line(capability)
    effect = if capability[:swallows_prompt]
               'DESCARTA el prompt'
             elsif capability[:renders_prompt]
               'el prompt se envía literal'
             else
               'conserva el prompt'
             end
    "- #{capability[:syntax]} — #{effect}.#{detail_text(capability)}#{usage_text(capability)}"
  end

  # Un ejemplo escrito con un valor real vale más que la plantilla de sintaxis.
  def usage_text(capability)
    builder = USAGE[capability[:key]]
    name = capability.dig(:detail, :names)&.first
    return '' if builder.nil? || name.blank?

    " Se escribe así: #{builder.call(name)}"
  end

  # El `detail` del Registry es un Hash pensado para la UI. Volcarlo tal cual metía
  # «{:count=>16}» en el prompt: ruido que el modelo tiene que descifrar.
  def detail_text(capability)
    detail = capability[:detail]
    return '' if detail.blank?

    names = detail[:names]
    return " Disponibles: #{names.join(', ')}." if names.present?
    return ' No hay ninguna dada de alta.' if names.is_a?(Array)

    detail[:count].present? ? " Hay #{detail[:count]} en la cuenta." : ''
  end

  # F6: la guía de forma y el esqueleto son material del chat, no adorno de la UI.
  # Son las siete reglas extraídas de mirar los 27 agentes de producción.
  def form_guide
    reglas = AiAgentAssistant::PatternLibrary::FORM_RULES
             .each_with_index.map { |item, index| "#{index + 1}. #{item[:rule]}" }

    <<~TEXT.strip
      CÓMO SE VE UN AGENTE BIEN FORMADO (en orden de impacto)

      #{reglas.join("\n")}

      Estructura MÍNIMA del prompt complementario (el suelo, no el techo):
      #{AiAgentAssistant::PatternLibrary::SKELETON}
      Hay más secciones disponibles, listadas abajo. Un agente que solo recuerda algo se
      queda en este mínimo; uno que califica, agenda o cierra necesita más.
    TEXT
  end

  # El asistente puede PROPONER secciones. Los prompts de producción buenos tienen
  # una arquitectura mucho más rica que el esqueleto de cinco, y el usuario no tiene
  # por qué saber que existe: ofrecérsela es media pieza del asistente.
  def section_guide
    presentes = AiAgentAssistant::PatternLibrary.sections_in(
      session.merged_draft['complementary_prompt']
    )
    catalogo = AiAgentAssistant::PatternLibrary::SECTION_PURPOSE
               .except('config')
               .map { |key, purpose| "- [#{key.upcase}] #{purpose}" }

    <<~TEXT.strip
      SECCIONES QUE PUEDES PROPONER

      #{catalogo.join("\n")}

      #{presentes_text(presentes)}

      Cómo se ofrecen:
      - Ofrece, no impongas, y pregunta antes de escribirla: «¿le agregamos una sección de
        post-cierre? sin ella el agente vuelve a preguntar después de despedirse».
      - Propón solo lo que el caso que te contó el usuario justifica. Un agente que solo
        recuerda un pago no necesita arquitectura de estados ni nodos literales.
      - Los diez agentes más sanos de la base instalada NO tienen ninguna sección: son
        prompts de 500 a 760 caracteres. Más secciones no es mejor agente.
      - Si el usuario describe que hay que reunir datos antes de dar algo (una liga, una
        cita, un precio), ESCRIBE [SLOTS] con la pregunta literal de cada dato, [CIERRE] y
        [POSTCIERRE]. Es la combinación que resuelve ese caso en producción, y meterla
        resumida en [ROL Y LÍMITES] no la resuelve: el agente vuelve a preguntar.
      - Si te dice «que no vuelva a preguntar después de X», eso es [POSTCIERRE] y va como
        sección propia, no como una frase suelta.
    TEXT
  end

  def presentes_text(presentes)
    return 'El prompt actual no tiene ninguna sección todavía.' if presentes.empty?

    "El prompt actual ya trae estas secciones, no las propongas otra vez: #{presentes.join(' · ')}."
  end

  # F6 en el chat: los bloques que el usuario referenció escribiendo «$» en su
  # mensaje. Entran solo cuando se piden —meter los 28 en cada turno sería pagar el
  # catálogo entero para no usar ninguno— y entran con su evidencia, porque lo que
  # convence al usuario de aceptar un bloque no es el bloque: es de dónde salió.
  def referenced_patterns
    blocks = resolved_references
    return nil if blocks.empty?

    <<~TEXT.strip
      PATRONES QUE EL USUARIO TE SEÑALÓ CON «$»

      Son EJEMPLOS sacados de agentes de producción, no texto para pegar. Cada uno trae
      <huecos>: rellénalos con lo que este usuario ya te contó de su negocio, y lo que no
      te haya contado, pregúntaselo. Nunca propongas un prompt con un <hueco> sin rellenar.
      Adapta la redacción a su caso; lo que se copia es la idea, no las palabras.

      #{blocks.map { |block| reference_text(block) }.join("\n\n")}
    TEXT
  end

  def resolved_references
    keys = AiAgentAssistant::PatternLibrary.references_in(referenced_text)
    return [] if keys.empty?

    library = AiAgentAssistant::PatternLibrary.for(
      account: account, inbox: inbox, template: session.tracking_template,
      prompt: session.merged_draft['complementary_prompt']
    )
    library[:blocks].select { |block| keys.include?(block[:key]) }
                    .first(AiAgentAssistant::PatternLibrary::MAX_REFERENCES)
  end

  # Todo lo que ha escrito el usuario, no solo el último mensaje: si referenció un
  # bloque y dos turnos después dice «ese, pero más corto», el texto sigue haciendo falta.
  def referenced_text
    session.messages.select { |message| message['role'] == 'user' }.pluck('content').join("\n")
  end

  def reference_text(block)
    [
      "$#{block[:key]} — sección [#{block[:section].upcase}]#{reference_status(block)}",
      block[:body],
      "Por qué existe: #{block[:source]}"
    ].join("\n")
  end

  # Un bloque puede estar bien escrito y no servir AQUÍ. Si el asistente no lo sabe,
  # lo propone igual y el motor lo descarta sin que nadie se entere.
  def reference_status(block)
    case block[:status]
    when 'dead_letter'
      ' — OJO: en este agente el motor descarta el prompt entero. Dilo y no lo propongas.'
    when 'unavailable'
      ' — OJO: la capacidad que necesita no está encendida en esta cuenta. Dilo y no lo propongas.'
    when 'source_taken'
      ' — OJO: este agente ya tiene una fuente y solo una resuelve el turno. Dilo antes de proponerlo.'
    else
      ''
    end
  end

  def mode_instructions
    case session.mode
    when 'interview'
      'MODO ENTREVISTA. El agente se arma de cero. Sigue el guion de abajo, un paso por turno.'
    when 'audit'
      <<~TEXT.strip
        MODO AUDITAR. El usuario ya tiene un prompt (normalmente escrito en ChatGPT, que no
        conoce este motor). Diseccionalo: qué sobra porque no cabe, qué se anula por una
        directiva de búsqueda, qué directivas chocan entre sí, qué da por hecho que aquí no
        existe. Entrega los cambios de uno en uno, no una reescritura.
      TEXT
    else
      <<~TEXT.strip
        MODO AJUSTE. El usuario pide un cambio puntual sobre algo que ya funciona. Haz el
        diff mínimo: toca solo lo que pidió y deja el resto intacto.
      TEXT
    end
  end

  def interview_guide
    return nil unless session.mode == 'interview'

    step = AiAgentAssistant::Interview.step(session.step) || AiAgentAssistant::Interview.steps.first
    tree = knowledge_tree_text if step[:key] == 'knowledge'
    tree = architecture_tree_text if step[:key] == 'purpose'

    <<~TEXT.strip
      PASO ACTUAL DE LA ENTREVISTA: #{step[:key]} (#{position_of(step)} de #{AiAgentAssistant::Interview.steps.size})
      Pregunta a cubrir: #{step[:question]}
      Por qué importa (úsalo si el usuario pregunta, no lo sueltes de entrada): #{step[:why]}
      #{tree}
    TEXT
  end

  def position_of(step)
    AiAgentAssistant::Interview.steps.index { |s| s[:key] == step[:key] }.to_i + 1
  end

  # El árbol de FORMA. Es la indagación del propósito: de aquí sale qué secciones
  # necesita el prompt, y sobre todo cuáles NO.
  def architecture_tree_text
    tree = AiAgentAssistant::Interview.architecture_tree
    lines = tree[:options].map do |option|
      secciones = option[:sections].map { |key| "[#{key.upcase}]" }.join(' ')
      "  · #{option[:label]}\n      → secciones: #{secciones}\n      #{option[:note]}"
    end

    <<~TEXT.strip

      INDAGACIÓN DEL PROPÓSITO — #{tree[:question]}
      #{lines.join("\n")}

      Pregunta por el negocio hasta encajarlo en una de las cuatro formas, y DILE cuál es y
      qué secciones trae. Si es la primera, dilo también: sobrarían secciones.
      Cuando la forma esté clara, escribe el prompt con ESAS secciones y sus encabezados
      entre corchetes, dejando <huecos> donde falte información del negocio.
    TEXT
  end

  # El árbol de §13.6, ya podado: el modelo solo ve ramas que esta cuenta puede usar.
  def knowledge_tree_text
    tree = AiAgentAssistant::Interview.knowledge_tree(
      account: account, inbox: inbox, template: session.tracking_template
    )
    lines = tree[:options].map do |option|
      syntax = option[:capability] ? AiAgentAssistant::Capabilities.find(option[:capability])[:syntax] : 'ninguna directiva'
      "  · #{option[:label]} → #{syntax}#{option[:note] ? " (#{option[:note]})" : ''}"
    end

    <<~TEXT.strip

      ÁRBOL DE SELECCIÓN PARA ESTE PASO — #{tree[:question]}
      #{lines.join("\n")}
      Se pueden sumar a cualquier rama, sin coste: #{tree[:addons].join(', ').presence || 'ninguna'}.
      No preguntes «¿qué directiva quieres?». Pregunta por el negocio y elige tú.

      IMPORTANTE: tú no ejecutas nada. La directiva es TEXTO que va dentro de
      `complementary_prompt`, y es el motor quien la resuelve en cada conversación real,
      con los datos de ese contacto. Así que no pidas al usuario el nombre de un cliente
      ni ningún dato concreto: propón la directiva escrita, tal cual, en el campo.
    TEXT
  end

  def current_draft
    draft = session.merged_draft.compact_blank
    return 'BORRADOR ACTUAL: vacío, todavía no hay nada.' if draft.blank?

    lines = draft.map { |field, value| "#{field}: #{value.to_s.truncate(600)}" }
    "BORRADOR ACTUAL (lo que llevas hasta ahora):\n#{lines.join("\n")}"
  end

  def output_contract
    <<~TEXT.strip
      FORMATO DE RESPUESTA — devuelve SIEMPRE un JSON con esta forma exacta:

      {
        "reply": "lo que le dices al usuario. Una sola pregunta al final, si toca preguntar.",
        "proposals": [
          {"field": "objective", "value": "texto propuesto", "rationale": "por qué, en una línea"}
        ],
        "next_step": "clave del paso siguiente, o null para que avance solo",
        "done": false
      }

      Si anuncias un cambio, va en `proposals` en ESE MISMO turno. Decir «voy a proponer
      los campos» y mandar `proposals` vacío es un error: el usuario no ve nada.
      `proposals` va vacío solo si en este turno de verdad no cambias ningún campo. Los campos
      válidos son: #{AiAgentAssistantSession::DRAFT_FIELDS.join(', ')}.
      `keyword_actions` es una lista de objetos {keyword, action, direction}, donde
      `action` es una de #{ContactTrackings::KeywordActionService::VALID_ACTIONS.join(' | ')} y
      `direction` una de #{ContactTrackings::KeywordActionService::VALID_DIRECTIONS.join(' | ')}.
      `retry_interval_unit` solo admite #{AiAgentAssistant::ConversationService::ENUM_FIELDS['retry_interval_unit'].join(' | ')}
      (en inglés, aunque hables en español) y `slots_presentation` solo
      #{AiAgentAssistant::ConversationService::ENUM_FIELDS['slots_presentation'].join(' | ')}.
      `timezone` es un identificador IANA, por ejemplo America/Mexico_City.
      Ojo: `slots_presentation` es cómo se le muestran los HORARIOS de calendario al cliente.
      No tiene nada que ver con los datos que el agente deba reunir; esos van en el prompt.
      `inbox_id` es el número de uno de los canales listados arriba.
      Las claves de paso válidas para `next_step` son:
      #{AiAgentAssistant::Interview.steps.pluck(:key).join(' → ')}.
      Déjalo en null y el guion avanzará solo cuando el paso quede cubierto; repite la clave
      actual solo si necesitas insistir en la misma pregunta.
      `done` es true solo cuando el borrador está completo y ya no tienes más que preguntar.
    TEXT
  end
end
