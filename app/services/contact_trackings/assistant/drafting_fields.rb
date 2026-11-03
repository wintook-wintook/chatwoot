# frozen_string_literal: true

# ================================================================================
# proyecto@crear_agente_conversando — F3: LO QUE LA CONVERSACIÓN LLENA APARTE
# ================================================================================
# Plan: docs/creacion_conversacional_agentes_plan.md §6. Además de las instrucciones,
# el chat de creación (DraftingChat) devuelve la Definición, las Variables y los Datos
# fijos del agente en listas. Aquí se limpian y se pasan al formato que ya entienden
# el motor, el comprobador y los modales de F1/F2:
#
#   "variables":   [{ "nombre": "SISTEMA", "valores": ["CONTPAQi", "Aspel"], "libre": false, "inicial": null }]
#     → cuerpo de [VARIABLES]      SISTEMA = CONTPAQi | Aspel
#   "datos_fijos": [{ "nombre": "Q1", "tipo": "pregunta", "contenido": "¿Qué sistema usas?", "guarda_en": "SISTEMA" }]
#     → cuerpo de [DATOS FIJOS]    Q1 (pregunta) = ¿Qué sistema usas? → guarda en SISTEMA
#   "definicion":  { "objetivo": "…", "contexto": "…" }
#     → { 'objective' => …, 'ai_context' => … }  (las columnas del agente, en proposal)
#
# Variables y Datos fijos se guardan en la conversación como el TEXTO de su sección:
# así lo que se edita en el modal, lo que ve el modelo en el turno siguiente y lo que
# el redactor copia al Entrenamiento son exactamente lo mismo.
#
# nil = el modelo no lo cambió en este turno (o mandó algo que no sirve). Una lista
# vacía también es nil: medido con las instrucciones, el modelo devuelve [] cuando no
# tiene nada nuevo, no cuando quiere borrar. Borrar se hace en el modal.
# ================================================================================

module ContactTrackings::Assistant::DraftingFields
  NAME_RE = /\A[A-ZÁÉÍÓÚÑ][A-ZÁÉÍÓÚÑ0-9_]*\z/
  FREE_WORD = 'valor'
  MAX_VARIABLES = 20
  MAX_OPTIONS = 15
  MAX_CONSTANTS = 30
  MAX_VALUE = 1_500
  MAX_OBJECTIVE = 500
  # Lo que el motor lee del Contexto (project_motor_limites_prompt).
  MAX_CONTEXT = 800
  CONSTANT_TYPES = ContactTrackings::PromptConstants::TYPES
  TYPE_ALIASES = ContactTrackings::PromptConstants::TYPE_ALIASES
  KEYS = %w[objective ai_context variables datos_fijos].freeze
  MAX_ROUTE_LINES = 40

  module_function

  # Lo que devolvió el modelo, ya limpio; solo las llaves que cambiaron.
  def from_reply(raw)
    definition(raw['definicion']).to_h
                                 .merge('variables' => variables_text(raw['variables']),
                                        'datos_fijos' => constants_text(raw['datos_fijos']))
                                 .compact
  end

  # { 'objective' => …, 'ai_context' => … } con lo que vino; nil si no vino nada.
  def definition(raw)
    return nil unless raw.is_a?(Hash)

    { 'objective' => raw['objetivo'].to_s.strip.truncate(MAX_OBJECTIVE),
      'ai_context' => raw['contexto'].to_s.strip.truncate(MAX_CONTEXT) }.compact_blank.presence
  end

  # El cuerpo de [VARIABLES], o nil.
  def variables_text(raw)
    variables = unique(Array(raw).first(MAX_VARIABLES).filter_map { |v| variable(v) })
    return nil if variables.empty?

    iniciales = variables.select { |v| v[:initial] }.map { |v| "#{v[:name]}=#{v[:initial]}" }
    [*variables.map { |v| variable_line(v) }, ("Inicial: #{iniciales.join('; ')}" if iniciales.any?)].compact.join("\n")
  end

  def variable_line(variable)
    valores = variable[:options] + (variable[:free] ? [FREE_WORD] : [])
    "#{variable[:name]} = #{valores.join(' | ')}"
  end

  # La primera con cada nombre.
  def unique(lista) = lista.uniq { |item| item[:name] }

  # El cuerpo de [DATOS FIJOS], o nil.
  def constants_text(raw)
    constantes = unique(Array(raw).first(MAX_CONSTANTS).filter_map { |c| constant(c) })
    constantes.any? ? constantes.map { |c| declaration(c) }.join("\n") : nil
  end

  # Solo las líneas de rutas del boceto (FR/D10): no lleva prosa.
  def routes_text(texto)
    lineas = texto.to_s.split("\n").map(&:strip).select { |l| l.start_with?('@ruta') }
    lineas.any? ? lineas.first(MAX_ROUTE_LINES).join("\n") : nil
  end

  # "Sistema actual" → "SISTEMA_ACTUAL"; nil si no queda un nombre.
  def clean_name(texto)
    nombre = texto.to_s.strip.upcase.tr('%', '').gsub(/[^A-ZÁÉÍÓÚÑ0-9_]+/, '_').gsub(/\A[_0-9]+|_+\z/, '')
    nombre.match?(NAME_RE) ? nombre : nil
  end

  def variable(raw)
    return nil unless raw.is_a?(Hash)

    nombre = clean_name(raw['nombre'])
    return nil if nombre.nil?

    opciones = options(raw['valores'])
    libre = ActiveModel::Type::Boolean.new.cast(raw['libre']) || opciones.empty?
    { name: nombre, options: opciones, free: libre, initial: initial(raw['inicial'], opciones, libre) }
  end

  # Sin barras ni punto y coma dentro de un valor: partirían la declaración.
  def options(raw)
    lista = raw.is_a?(Array) ? raw : raw.to_s.split('|')
    lista.map { |o| o.to_s.tr('|;', ' ').squish }.compact_blank
         .reject { |o| o.casecmp?(FREE_WORD) }.uniq(&:downcase).first(MAX_OPTIONS)
  end

  # El inicial tiene que ser uno de los valores (V3), salvo en una variable libre.
  def initial(raw, opciones, libre)
    valor = raw.to_s.tr('|;', ' ').squish
    return nil if valor.blank? || valor.casecmp?('null')
    return valor if libre

    opciones.find { |o| o.casecmp?(valor) }
  end

  def constant(raw)
    return nil unless raw.is_a?(Hash)

    nombre = clean_name(raw['nombre'])
    contenido = raw['contenido'].to_s.strip.truncate(MAX_VALUE)
    return nil if nombre.nil? || contenido.blank?

    tipo = type(raw['tipo'])
    { name: nombre, type: tipo, value: contenido, saves_to: tipo == 'pregunta' ? clean_name(raw['guarda_en']) : nil }
  end

  def type(raw)
    tipo = raw.to_s.strip.downcase
    tipo = TYPE_ALIASES.fetch(tipo, tipo)
    CONSTANT_TYPES.include?(tipo) ? tipo : 'texto'
  end

  # Un valor de varios renglones sigue con sangría de dos espacios (PromptConstants).
  def declaration(constante)
    primera, *resto = constante[:value].split("\n")
    tipo = constante[:type] == 'texto' ? '' : " (#{constante[:type]})"
    guarda = constante[:saves_to] ? " → guarda en #{constante[:saves_to]}" : ''
    ["#{constante[:name]}#{tipo} = #{primera.strip}#{guarda}", *resto.map { |l| l.strip.present? ? "  #{l.strip}" : '' }]
      .join("\n")
  end
end
