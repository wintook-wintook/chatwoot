# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — EL ENCARGO, YA RESUELTO, PARA ESCRIBIR (F3 de docs/importar_prompt_md_plan.md)
# ================================================================================
# La ficha del encargo + lo que la persona contestó en el modal → UN mensaje para la
# redacción de una sola vez del Asistente (InterviewService one_shot). No se escribe
# un redactor nuevo: el que ya existe comprueba con el parser real y se corrige solo.
#
# Por qué en el modal y no en el chat (decisión del usuario, 23/09): el chat está
# escondido (SHOW_CHAT en Assistant.vue). Las preguntas son las mismas cuatro de la
# entrevista más las contradicciones; lo que se deje sin contestar sale <PENDIENTE:>.
#
# También arma la Definición del agente desde la ficha, sin IA: el objetivo, y los
# datos del negocio como Contexto SOLO si caben en lo que el motor lee de él (800
# caracteres, ver project_motor_limites_prompt); si no caben, se le pide al redactor
# que los ponga como sección, que no se recorta.
#
# RESPUESTAS (lo que manda el modal, todo opcional):
#   contradicciones  { "0" => "a" | "b" }        índice en la ficha → cuál vale
#   modo             "responde" | "deriva"
#   temas            "texto libre"                si el encargo no traía temas
#   frases           { "tema" => "una por renglón" }
#   fuentes          { "tema" => "de dónde / qué hace si no resuelve" }
#   etiquetas        { "tema" => "#etiqueta" }
# ================================================================================

class ContactTrackings::Assistant::BriefComposer
  Ficha = ContactTrackings::Assistant::BriefFicha

  CONTEXT_MAX_CHARS = 800
  # Con qué empieza el mensaje que arma esta clase, y de dónde se saca el archivo: el
  # título de la conversación en «En construcción» lo usa (TrackingAssistantSession#title).
  HEADER_START = 'Arma el Entrenamiento de un agente a partir de estas INSTRUCCIONES INICIALES'
  # Cómo empezaba antes del 23/09/2026 (voseo y «encargo»): conversaciones guardadas
  # con ese inicio siguen titulándose con el archivo.
  LEGACY_HEADER_STARTS = ['Armá el Entrenamiento de un agente a partir de este ENCARGO'].freeze
  FILENAME_RE = /archivo «([^»]+)»/
  SIDES = %w[a b].freeze
  # Las acciones van después de la flecha: medido el 23/09 con el gimnasio,
  # @agendar_calendar quedó del lado de la fuente y el motor la ignoraba.
  ACTION_TOOLS = %w[agenda ticket].freeze
  LISTS = { 'reglas' => 'REGLAS', 'prohibiciones' => 'PROHIBICIONES (nunca)', 'tono' => 'TONO',
            'datos_a_pedir' => 'DATOS QUE TIENE QUE PEDIR', 'fuera' => 'FUERA DEL AGENTE (no lo hace)' }.freeze

  # "📎 encargo_gimnasio.md" si el mensaje es uno armado acá; nil si no.
  def self.title_for(mensaje)
    return nil unless mensaje.to_s.start_with?(HEADER_START, *LEGACY_HEADER_STARTS)

    "📎 #{mensaje[FILENAME_RE, 1] || '.md'}"
  end

  # El texto de las reglas que la persona descartó al decidir una contradicción. Lo usa
  # también BriefCoverage: una descartada no se vuelve a agregar.
  def self.discarded(ficha, answers)
    Array(ficha['contradicciones']).each_with_index.filter_map do |c, i|
      lado = answers.to_h.deep_stringify_keys.dig('contradicciones', i.to_s)
      c[lado == 'a' ? 'b' : 'a'] if SIDES.include?(lado)
    end.to_set
  end

  # inventory: el de InventoryService; de ahí salen las directivas EXACTAS de la cuenta
  # para cada herramienta (ver BriefTools).
  def initialize(brief, answers: {}, inventory: {})
    @brief = brief
    @inventory = inventory
    @ficha = brief.digest['ficha'] || {}
    @answers = (answers.respond_to?(:to_unsafe_h) ? answers.to_unsafe_h : answers.to_h).deep_stringify_keys
  end

  # { message:, proposal: { objective:, ai_context: } }
  def call
    { message: message, proposal: proposal }
  end

  private

  def message
    [header, identity, topics, tools, *lists, knowledge_block, decisions, closing].compact.join("\n\n")
  end

  # Medido el 23/09 con el gimnasio: sin el "NADA SE PIERDE", la redacción de una sola
  # vez dejó 1.600 caracteres y se comió "una sola pregunta por mensaje", "máximo 3
  # renglones", los datos a pedir y la decisión de la persona sobre el precio.
  def header
    <<~TXT.strip
      #{HEADER_START}: la idea de cómo lo quiere la persona, ya
      leída y resumida del archivo «#{@brief.filename}». Escríbelo en el formato del motor. Cada
      tema es una ruta. Lo que falte, <PENDIENTE: qué falta>.

      ⚠ NADA SE PIERDE: cada regla, prohibición, punto de tono, dato a pedir y decisión de la
      persona de abajo tiene que quedar en el Entrenamiento, en su sección ([REGLAS],
      [PROHIBIDO], [ESTILO], [DATOS A PEDIR]…), con sus palabras o más claras, nunca resumida
      hasta perderse. Escribe en el idioma de las instrucciones.

      Cada ruta lleva su #etiqueta y el motor la agrega sola a sus respuestas. [ETIQUETAS]
      es un diccionario: «#etiqueta = cuándo se usa», una por línea. Nunca una etiqueta
      suelta, sin significado: se pega a TODAS las respuestas (medido: un agente cerraba
      cada mensaje con #humano).
    TXT
  end

  def identity
    [line('QUIÉN ES', @ficha['identidad']), line('OBJETIVO', @ficha['objetivo']),
     "CÓMO ATIENDE: #{modo || '<PENDIENTE: contesta o deriva>'}"].compact.join("\n")
  end

  def modo
    elegido = @answers['modo'].to_s
    Ficha::MODES.include?(elegido) ? elegido : @ficha.dig('modo', 'texto')
  end

  def topics
    temas = Array(@ficha['temas'])
    return "TEMAS (cada uno es una ruta): #{@answers['temas'].presence || '<PENDIENTE: qué temas atiende>'}" if temas.empty?

    (['TEMAS (cada uno es una ruta):'] + temas.map { |t| topic_line(t) }).join("\n")
  end

  # Lo que contestó la persona manda sobre lo que traía el encargo.
  def topic_line(tema)
    nombre = tema['nombre']
    frases = answered_list('frases', nombre).presence || Array(tema['frases_cliente'])
    fuente = [tema['fuente'], tema['si_no_resuelve'], @answers.dig('fuentes', nombre)].compact_blank
    etiqueta = (@answers.dig('etiquetas', nombre).presence || tema['etiqueta']).to_s.delete_prefix('#')
    partes = { 'qué hace' => tema['que_hace'], 'el cliente escribe' => frases.map { |f| "«#{f}»" }.join(', '),
               'fuente / si no resuelve' => fuente.join(' · '), 'etiqueta' => etiqueta.presence&.prepend('#') }
    (["- #{nombre}"] + partes.compact_blank.map { |titulo, valor| "#{titulo}: #{valor}" }).join(' · ')
  end

  def answered_list(campo, tema)
    @answers.dig(campo, tema).to_s.split("\n").map(&:strip).compact_blank
  end

  def tools
    lista = Array(@ficha['herramientas']).map do |h|
      "- #{h['tipo']}: #{h['para']}#{tool_hint(h['tipo'])}"
    end
    lista.any? ? (['HERRAMIENTAS:'] + lista).join("\n") : nil
  end

  # Las directivas reales de la cuenta, o <PENDIENTE> si no tiene ninguna.
  def tool_hint(tipo)
    directivas = ContactTrackings::Assistant::BriefTools.directives(tipo, @inventory)
    return '' if directivas.nil?
    return ' → la cuenta NO la tiene conectada: <PENDIENTE>' if directivas.empty?

    lista = directivas.first(8).join(' · ')
    # Medido el 24/09 con el consultorio: con la misma frase que las fuentes, la
    # agenda quedó como «<PENDIENTE: cuál> -> @agendar_calendar».
    if ACTION_TOOLS.include?(tipo)
      return " → las de la cuenta: #{lista}. Es una ACCIÓN: va después de la flecha, y si esa ruta no " \
             'consulta ninguna fuente, antes de la flecha va «-» (ej. @ruta(…): - -> ACCIÓN)'
    end

    " → las de la cuenta: #{lista}. Usa una tal cual SOLO si es la que " \
      'piden las instrucciones; si ninguna lo es, <PENDIENTE: cuál>'
  end

  def lists
    LISTS.filter_map do |campo, titulo|
      puntos = Array(@ficha[campo]).reject { |p| discarded.include?(p['texto']) }.map { |p| "- #{p['texto']}" }
      puntos.any? ? (["#{titulo}:"] + puntos).join("\n") : nil
    end
  end

  # Los datos del negocio y lo consultable. Si ya van como Contexto, no se repiten.
  def knowledge_block
    return nil if knowledge.empty? || context_fits?

    (['DATOS DEL NEGOCIO Y CONOCIMIENTO (ponlos como una sección del Entrenamiento):'] +
      knowledge.map { |k| "- #{k}" }).join("\n")
  end

  def knowledge
    @knowledge ||= Array(@ficha['conocimiento']).map { |c| "#{c['tema']}: #{c['resumen']}" }
  end

  def context_fits?
    knowledge.any? && knowledge.join("\n").length <= CONTEXT_MAX_CHARS
  end

  # Lo que la persona decidió en las contradicciones: la que vale entra, la otra no
  # (y se saca de las listas, ver #discarded). Sin elegir, queda <PENDIENTE:> con las
  # dos opciones a la vista.
  def decisions
    lineas = contradictions.map do |c, lado|
      next "- Sobre «#{c['sobre']}» las instrucciones se contradicen: <PENDIENTE: «#{c['a']}» o «#{c['b']}»>" if lado.nil?

      "- Sobre «#{c['sobre']}»: vale «#{c[lado]}». NO pongas «#{c[other(lado)]}»."
    end
    lineas.any? ? (['DECISIONES DE LA PERSONA:'] + lineas).join("\n") : nil
  end

  # [[contradicción, 'a' | 'b' | nil]]
  def contradictions
    Array(@ficha['contradicciones']).each_with_index.map do |c, i|
      lado = @answers.dig('contradicciones', i.to_s)
      [c, SIDES.include?(lado) ? lado : nil]
    end
  end

  def other(lado) = lado == 'a' ? 'b' : 'a'

  def discarded
    @discarded ||= self.class.discarded(@ficha, @answers)
  end

  def closing
    'Al final del "mensaje", enumera lo que quedó <PENDIENTE:>.'
  end

  def line(titulo, punto)
    texto = punto.is_a?(Hash) ? punto['texto'] : punto
    texto.present? ? "#{titulo}: #{texto}" : nil
  end

  def proposal
    { objective: @ficha.dig('objetivo', 'texto').to_s, ai_context: context_fits? ? knowledge.join("\n") : '' }
  end
end
