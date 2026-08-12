# ================================================================================
# proyecto@ai_agent_assistant - F5
# ================================================================================
# Servicio: AiAgentAssistant::Interview
# Descripción: El guion de la entrevista y el árbol de selección de directivas.
#
# Es la pieza determinista del chat: qué se pregunta, en qué orden, y qué
# capacidad corresponde a cada respuesta. El modelo redacta; el guion decide.
#
# Motivo (§13.6 del plan): los 27 agentes de la cuenta 568 no fallan por estar mal
# escritos —hay prompts excelentes ahí— sino por elegir mal la directiva o no
# elegir ninguna. La cuenta tiene las cuatro features de conocimiento activas y
# usa una sola: `@discourse`, justo en los tres agentes de 11 052 caracteres, o
# sea la única búsqueda que les destruye el prompt. Este árbol es la pregunta que
# ninguno de esos 27 agentes se hizo.
#
# Los textos van en español porque son contenido que el asistente dice, no
# etiquetas de interfaz: forman parte de la especificación de comportamiento
# (Anexo A del plan), no del i18n.
# ================================================================================

class AiAgentAssistant::Interview
  # El guion, en orden. `field` es lo que la respuesta alimenta; nil = el paso
  # afina el tono o los límites y acaba dentro del prompt complementario.
  STEPS = [
    { key: 'objective', field: 'objective',
      question: '¿Qué tiene que haber pasado para que des este seguimiento por cumplido?',
      why: 'De esto depende cuándo el agente deja de insistir. Es además el único campo que ' \
           'llega íntegro al modelo en las dos rutas, pase lo que pase con el prompt.' },
    { key: 'purpose', field: nil,
      question: '¿Tu agente solo avisa de algo, o tiene que conseguir algo del cliente antes ' \
                'de darle lo que pide?',
      why: 'Es la pregunta que decide la FORMA del prompt. Un agente que solo recuerda un ' \
           'pago cabe en cinco líneas; uno que califica antes de entregar una liga necesita ' \
           'secciones de datos, cierre y post-cierre, o vuelve a preguntar después de cerrar.' },
    { key: 'audience', field: nil,
      question: '¿A quién le escribe? ¿Qué trato usa: de tú o de usted?',
      why: 'Fija la voz del agente. Va a la sección [ROL Y LÍMITES].' },
    { key: 'channel', field: 'inbox_id',
      question: '¿Por qué canal escribe, y cada cuánto debe reintentar?',
      why: 'En WhatsApp, pasadas 24 h sin respuesta la ventana se cierra: sin plantillas ' \
           'aprobadas, todo reintento posterior falla.' },
    { key: 'knowledge', field: 'complementary_prompt',
      question: '¿Tu agente necesita tener voz propia, o solo necesita acertar?',
      why: 'Es la pregunta que decide la directiva de conocimiento, y la que separa un agente ' \
           'que funciona de uno cuyo prompt el motor descarta.' },
    { key: 'actions', field: nil,
      question: '¿Qué debe hacer cuando el cliente dice que sí: agendar, levantar un ticket, ' \
                'pasar a una persona?',
      why: 'Las banderas de acción conviven con cualquier fuente, sin coste.' },
    { key: 'limits', field: nil,
      question: '¿Qué no debe hacer nunca? (dar precios, prometer plazos, diagnosticar)',
      why: 'Es la sección [PROHIBIDO]. Los agentes de producción que funcionan la tienen.' },
    { key: 'keywords', field: 'keyword_actions',
      question: '¿Qué palabras del cliente deberían cortar el seguimiento en seco?',
      why: 'Es el mecanismo determinista de cierre: no depende de que el modelo lo interprete.' }
  ].freeze

  # El árbol de §13.6. Cada hoja apunta a una capacidad del Registry (o a ninguna),
  # y arrastra la advertencia que le corresponde.
  KNOWLEDGE_TREE = {
    question: '¿El agente necesita saber algo que no cabe en 1 500 caracteres?',
    options: [
      { key: 'no_knowledge', label: 'No: con lo que le escriba basta', capability: nil,
        note: 'Es la familia más sana de la base instalada (SEG01–SEG10): prompts de 500–760 ' \
              'caracteres, sin directivas que no necesitan.' },
      { key: 'exact_data', label: 'Sí, un dato exacto de un sistema (saldo, vencimiento, folio)',
        capability: :consulta,
        note: 'Ojo: con {{consulta:}} el prompt deja de ser una instrucción y pasa a ser el ' \
              'mensaje literal que recibe el cliente. Escríbelo como se lo dirías tú.' },
      { key: 'own_voice', label: 'Sí, y además necesita voz propia, flujo o adjuntos',
        capability: :doc,
        alternatives: [:hoja],
        note: 'Única vía que conserva el prompt: {{doc:}} para texto, {{hoja:}} para datos ' \
              'de una hoja de cálculo.' },
      { key: 'just_answer', label: 'Sí, pero solo necesita acertar; la personalidad da igual',
        capability: nil, children: :search,
        note: 'Las cuatro búsquedas descartan el prompt entero: las reglas se mudan al objetivo.' }
    ]
  }.freeze

  # El árbol de FORMA. Cada respuesta dice qué secciones necesita el prompt — y, casi
  # siempre, que no necesita ninguna. Los diez agentes más sanos de la base instalada
  # son de la primera rama: 500 a 760 caracteres y ni una sección.
  ARCHITECTURE_TREE = {
    question: '¿Qué tiene que hacer el agente, en una frase?',
    options: [
      { key: 'notify', label: 'Solo avisar o recordar algo, y registrar la respuesta',
        sections: %w[rol cierre],
        note: 'Es la familia más sana de la instalación. No le pongas más de lo que necesita.' },
      { key: 'answer', label: 'Responder dudas con información que ya existe',
        sections: %w[rol fuente prohibido],
        note: 'Aquí lo que decide es de dónde sale la información, no la arquitectura.' },
      { key: 'qualify', label: 'Reunir varios datos antes de entregar algo (una liga, una cita, un precio)',
        sections: %w[rol arquitectura apertura slots interrupciones cierre postcierre nodos prohibido],
        note: 'La forma más exigente, y la que más se rompe. Sin post-cierre el agente ' \
              'vuelve a preguntar después de despedirse; sin nodos literales, la liga sale ' \
              'distinta cada vez.' },
      { key: 'execute', label: 'Ejecutar algo cuando el cliente acepta: agendar o levantar un ticket',
        sections: %w[rol banderas flujo cierre],
        note: 'El motor ya pide los datos obligatorios uno por uno: el prompt acompaña, no ' \
              'reemplaza.' }
    ]
  }.freeze

  def self.architecture_tree
    ARCHITECTURE_TREE
  end

  # Las secciones que corresponden a una forma. Vacío si la forma no se reconoce.
  def self.sections_for(shape)
    ARCHITECTURE_TREE[:options].find { |option| option[:key] == shape.to_s }&.fetch(:sections) || []
  end

  SEARCH_BRANCH = {
    question: '¿Dónde vive ese acervo?',
    options: [
      { key: 'canned', label: 'Respuestas cortas y curadas por el equipo', capability: :buscar_predefinidas },
      { key: 'articles', label: 'Artículos largos del Centro de Ayuda', capability: :buscar_articulo },
      { key: 'source', label: 'Una fuente concreta del foro', capability: :buscar_foro },
      { key: 'forum', label: 'Todo el foro del inbox', capability: :discourse }
    ]
  }.freeze

  # Se suman a cualquier rama sin competir por el turno.
  FREE_ADDONS = %i[agendar_calendar crear_ticket estado_ticket].freeze

  def self.steps
    STEPS
  end

  def self.step(key)
    STEPS.find { |s| s[:key] == key.to_s }
  end

  def self.first_step
    STEPS.first[:key]
  end

  def self.next_step(key)
    index = STEPS.index { |s| s[:key] == key.to_s }
    return nil if index.nil? || index >= STEPS.size - 1

    STEPS[index + 1][:key]
  end

  # El árbol podado contra el estado real de la cuenta: nunca ofrece lo que esa
  # cuenta no tiene encendido (invariante 2 del Anexo A — no inventa capacidades).
  def self.knowledge_tree(account:, inbox: nil, template: nil)
    available = AiAgentAssistant::Capabilities
                .resolve_for(account: account, inbox: inbox, template: template)
                .select { |c| c[:available] }
                .to_set { |c| c[:key] }

    {
      question: KNOWLEDGE_TREE[:question],
      options: KNOWLEDGE_TREE[:options].filter_map { |option| prune(option, available) },
      addons: FREE_ADDONS.select { |key| available.include?(key) }
    }
  end

  def self.prune(option, available)
    children = option[:children] == :search ? prune_search(available) : nil
    return nil if children && children[:options].empty?

    usable = usable_capabilities(option, available)
    return nil if option[:capability].present? && usable.empty?

    option.slice(:key, :label, :note)
          .merge(capability: usable.first, alternatives: usable.drop(1))
          .merge(children ? { children: children } : {})
  end
  private_class_method :prune

  # La rama «voz propia» vale mientras quede al menos una de sus vías ({{doc:}} o
  # {{hoja:}}); si la principal está apagada, se promueve la que sí esté.
  def self.usable_capabilities(option, available)
    [option[:capability], *option[:alternatives]].compact.select { |key| available.include?(key) }
  end
  private_class_method :usable_capabilities

  def self.prune_search(available)
    { question: SEARCH_BRANCH[:question],
      options: SEARCH_BRANCH[:options].select { |o| available.include?(o[:capability]) } }
  end
  private_class_method :prune_search
end
