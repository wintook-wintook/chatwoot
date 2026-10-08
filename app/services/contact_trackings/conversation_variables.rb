# frozen_string_literal: true

# ================================================================================
# proyecto@contact_tracking — VARIABLES QUE SE CONSERVAN EN LA CONVERSACIÓN
# ================================================================================
# Un Entrenamiento puede declarar variables en una sección [VARIABLES]:
#
#   [VARIABLES]
#   CARRERA=VACÍO|valor
#   SIGUIENTE_OFERTA=SIN_INSCRIPCION|PRIMERA_BECA|SEGUNDA_BECA|ULTIMA_BECA|AGOTADA
#   LIGA_ENTREGADA=NO|SÍ
#   Inicial: CARRERA=VACÍO; SIGUIENTE_OFERTA=SIN_INSCRIPCION; LIGA_ENTREGADA=NO.
#
# y otras secciones las leen y las cambian («Si CARRERA=VACÍO, pregunta…», «Marca
# LIGA_ENTREGADA=SÍ»). Antes nada las guardaba: el modelo tenía que deducirlas del
# historial en cada turno, y el historial se recorta (kb_history guarda los últimos
# turnos, el conversacional 20 mensajes). Una liga entregada hace 30 mensajes volvía a
# ser LIGA_ENTREGADA=NO.
#
# Ahora el motor las guarda en la conversación:
#   1. Al armar el prompt se le dicen al modelo los valores ACTUALES (rule_for).
#   2. El modelo cierra SIEMPRE con la línea «VARIABLES: NOMBRE=valor; …» con todas.
#      Medido (conv 360, gpt-4o): pedida solo «cuando cambie», ofreció la segunda beca
#      y no la escribió; la variable se quedó un paso atrás. Pedida siempre, la copia.
#   3. Esa línea se quita antes de enviar el mensaje y se guardan los valores válidos
#      que cambiaron (settle). Un valor fuera de la lista declarada se descarta y se
#      registra.
#
# «valor» (o «texto», «dato») en la lista declarada significa «lo que diga el cliente»:
# CARRERA=VACÍO|valor acepta VACÍO o cualquier texto.
#
# Se guardan por Agente IA en conversation.additional_attributes['agent_variables'] (la
# columna jsonb de Postgres, como kb_history; no en Redis: no caducan ni se pierden con
# un reinicio), así dos agentes en la misma conversación no se pisan las variables.
# ================================================================================

module ContactTrackings::ConversationVariables
  STORE_KEY = 'agent_variables'

  # La línea que escribe el modelo. Acepta «VARIABLES:», «VARIABLE:» y «[VARIABLES]:».
  UPDATE_RE = /\A[ \t]*\[?[ \t]*VARIABLES?[ \t]*\]?[ \t]*:[ \t]*(.+?)[ \t]*\z/i
  # La misma, pegada al final de una frase («…disponible ahora. VARIABLES: CARRERA=…»):
  # medido en la conv 364, llegaba al cliente. En mayúsculas, para no confundirla con
  # «las variables: …» de una respuesta normal.
  INLINE_RE = /[ \t]*\[?VARIABLES?\]?[ \t]*:[ \t]*(.+?)[ \t]*\z/

  module_function

  # NOMBRE normalizado para comparar: sin acentos, mayúsculas, espacios como guion bajo.
  def key(text)
    I18n.transliterate(text.to_s.strip).upcase.gsub(/\s+/, '_')
  end

  def parse(prompt)
    Definition.parse(prompt)
  end

  def definition_for(tracking)
    parse(tracking&.complementary_prompt)
  end

  def store_key(tracking)
    (tracking.tracking_template_id || "tracking_#{tracking.id}").to_s
  end

  # Los valores actuales: los iniciales, pisados por lo guardado en la conversación.
  def current(tracking, conversation, definition = definition_for(tracking))
    saved = conversation&.additional_attributes&.dig(STORE_KEY, store_key(tracking)) || {}
    definition.initial.merge(saved.transform_keys { |nombre| key(nombre) }.slice(*definition.variables.keys))
  end

  # El bloque del system prompt. nil si el Entrenamiento no declara [VARIABLES].
  def rule_for(tracking, conversation)
    definition = definition_for(tracking)
    return nil if definition.blank?

    values = current(tracking, conversation, definition)
    actuales = definition.variables.map { |clave, var| "#{var[:name]}=#{values[clave]}" }
    permitidos = definition.variables.values.map do |var|
      lista = var[:options].dup
      lista << 'el dato que dé el cliente' if var[:free]
      "#{var[:name]}: #{lista.join(' | ')}"
    end

    <<~RULE.chomp
      VARIABLES DE ESTA CONVERSACIÓN, ANTES de tu respuesta (las guarda el sistema y mandan sobre lo que deduzcas
      del historial). Describen lo que ya pasó; lo que vas a hacer en esta respuesta todavía no ha pasado:
      #{actuales.join("\n")}
      Decide qué hacer con esos valores. Después, termina SIEMPRE tu respuesta con una línea aparte (antes de la
      etiqueta de cierre, si la hay) con TODAS las variables y el valor que tienen después de este turno:
      VARIABLES: #{actuales.join('; ')}
      Si tus instrucciones te mandan marcar o cambiar una variable (por ejemplo porque ofreciste algo, entregaste algo
      o el cliente dio el dato que guarda), escribe ahí el valor nuevo; si no, copia el actual. El sistema quita esa
      línea antes de enviar el mensaje; el cliente nunca la ve, así que no la menciones.
      Valores permitidos:
      #{permitidos.join("\n")}
    RULE
  end

  # Quita las líneas de variables del texto y devuelve [texto_limpio, {NOMBRE => valor}]
  # con los cambios válidos. Además de «VARIABLES: …» se reconoce la línea suelta
  # «LIGA_ENTREGADA=SÍ» de una variable declarada: el modelo a veces copia la forma de
  # la sección [VARIABLES] en vez de la línea pedida.
  def extract(text, definition)
    return [text, {}] if text.blank? || definition.blank?

    changes = {}
    kept = text.split("\n", -1).filter_map do |linea|
      resto, pares = variable_pairs(linea, definition)
      next linea if pares.nil?

      pares.each { |nombre, valor| collect(changes, definition, nombre, valor) }
      resto.presence
    end

    [kept.join("\n").gsub(/\n{3,}/, "\n\n").strip, changes]
  end

  def collect(changes, definition, nombre, valor)
    value = definition.coerce(nombre, valor)
    if value
      changes[definition.variable(nombre)[:name]] = value
    else
      Rails.logger.warn "[Variables] ⚠️ Valor no declarado descartado: #{nombre}=#{valor}"
    end
  end

  # [lo que queda de la línea, pares] si la línea trae variables; nil si no.
  def variable_pairs(linea, definition)
    match = linea.match(UPDATE_RE) || linea.match(INLINE_RE)
    if match
      pares = match[1].scan(Definition::PAIR_RE)
      return [linea[0...match.begin(0)].rstrip, pares] if pares.any?
    end

    match = linea.match(Definition::DECL_RE)
    return nil unless match && definition.variable(match[1]) && match[2].exclude?('|')

    ['', [[match[1], match[2]]]]
  end

  # update_columns, como kb_history: no debe disparar callbacks ni eventos de la conversación.
  def apply!(tracking, conversation, changes)
    return if changes.blank? || conversation.nil?

    attrs = conversation.additional_attributes || {}
    variables = attrs[STORE_KEY].to_h.deep_dup
    variables[store_key(tracking)] = variables[store_key(tracking)].to_h.merge(changes)
    conversation.update_columns(additional_attributes: attrs.merge(STORE_KEY => variables)) # rubocop:disable Rails/SkipsModelValidations
    Rails.logger.info "[Variables] 💾 Conversación ##{conversation.id}: #{changes.map { |n, v| "#{n}=#{v}" }.join('; ')}"
  rescue StandardError => e
    Rails.logger.warn "[Variables] ⚠️ No se pudieron guardar las variables: #{e.message}"
  end

  # Quita la línea de variables de la respuesta y guarda los cambios. Devuelve el texto
  # que sí ve el cliente.
  def settle(tracking, conversation, text)
    definition = definition_for(tracking)
    return text if definition.blank?

    clean, changes = extract(text, definition)
    actuales = current(tracking, conversation, definition)
    apply!(tracking, conversation, changes.reject { |nombre, valor| actuales[key(nombre)] == valor })
    clean
  end

  # Solo quita la línea (para el historial que se guarda): no guarda nada.
  def strip(tracking, text)
    definition = definition_for(tracking)
    return text if definition.blank?

    extract(text, definition).first
  end
end
