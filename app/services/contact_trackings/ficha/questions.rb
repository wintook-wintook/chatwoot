# frozen_string_literal: true

# ================================================================================
# feat/ficha_agente_ia — LAS PREGUNTAS QUE EL AGENTE HACE, UNA A LA VEZ
# ================================================================================
# Pedido del usuario (10/11/2026): «el agente envía preguntas y al responder envía la
# siguiente; por eso se creó Datos fijos (preguntas)… asistir para eso y para Variables».
# La persona escribe las preguntas en orden; aquí se escriben las tres piezas que el
# motor ya entiende:
#
#   [VARIABLES]                       SISTEMA = CONTPAQi | Aspel      (o «= valor»: libre)
#   [DATOS FIJOS]                     Q1 (pregunta) = ¿Qué sistema usas? → guarda en SISTEMA
#   y cuándo se preguntan:
#     al inicio  → [PREGUNTAS] Antes de contestar lo demás, pregunto una a la vez…: %Q1%, %Q2%…
#     en una ruta → se agrega al alcance de esa ruta
#     con la bienvenida → como al inicio, y además la PRIMERA pregunta va al final de
#       [MENSAJE DE BIENVENIDA] (sin bienvenida, la sección se crea solo con ella): el motor
#       manda esa sección tal cual en el primer mensaje, así la conversación arranca
#       preguntando (pedido del usuario, 10/11/2026).
#
# read: lo que ya tiene un Entrenamiento. write: reemplaza SOLO las preguntas (los demás
# datos fijos y variables se quedan). Mismos patrones que PromptConstants y Variables.
# ================================================================================

class ContactTrackings::Ficha::Questions
  START = 'start'
  WELCOME = 'welcome'
  WELCOME_SECTION = 'MENSAJE DE BIENVENIDA'
  FILE_LINE_RE = /\A\s*\{\{[^}]+\}\}\s*\z/
  SECTION = 'PREGUNTAS'
  MAX = 10
  MAX_TEXT = 200
  MAX_OPTIONS = 15
  NOTE_RE = /\s*Antes de contestar, pregunto una a la vez y en este orden:.*?no la vuelvo a preguntar\./
  HEADER_RE = /\A[ \t]*\[([^\]\n]+)\][ \t]*\z/
  CONST_DECL_RE = ContactTrackings::PromptConstants::DECL_RE
  VAR_NAME_RE = /\A[ \t]*([A-ZÁÉÍÓÚÑ][A-ZÁÉÍÓÚÑ0-9_]*)[ \t]*=/

  # [{ 'text' =>, 'var' =>, 'options' => [] }] limpias.
  def self.clean(lista)
    Array(lista).first(MAX).each_with_index.filter_map do |pregunta, indice|
      h = (pregunta.respond_to?(:to_unsafe_h) ? pregunta.to_unsafe_h : pregunta.to_h).stringify_keys
      texto = h['text'].to_s.squish.first(MAX_TEXT)
      next if texto.blank?

      opciones = Array(h['options']).map { |o| o.to_s.tr('|', '/').squish }.compact_blank.uniq.first(MAX_OPTIONS)
      { 'text' => texto, 'var' => var_name(h['var'], indice), 'options' => opciones }
    end
  end

  def self.var_name(nombre, indice)
    limpio = I18n.transliterate(nombre.to_s).upcase.gsub(/[^A-Z0-9_]+/, '_').gsub(/\A[_0-9]+|_+\z/, '')
    limpio.presence || "RESPUESTA_#{indice + 1}"
  end

  # La frase de uso (va en [PREGUNTAS] o al final del alcance de una ruta).
  def self.note(nombres)
    "Antes de contestar, pregunto una a la vez y en este orden: #{nombres.map { |n| "%#{n}%" }.join(', ')}; " \
      'si ya tengo la respuesta en VARIABLES, no la vuelvo a preguntar.'
  end

  def initialize(text)
    @lines = text.to_s.split("\n", -1)
  end

  def text = @lines.join("\n").gsub(/\n{3,}/, "\n\n").strip

  # { questions: [...], when: 'start' | 'nombre_de_ruta' | nil }
  def read
    preguntas = stored_questions
    cuando = where_asked(preguntas.first&.dig('name'))
    cuando = WELCOME if cuando == START && in_welcome?(preguntas.first['text'])
    { questions: preguntas, when: cuando }
  end

  # La bienvenida que se edita (sin la primera pregunta, si va pegada a ella).
  def self.welcome_without(texto, lectura)
    return texto unless lectura[:when] == WELCOME

    primera = lectura[:questions].first['text']
    texto.to_s.lines.reject { |l| l.strip == primera }.join.strip
  end

  # cuando: START, WELCOME o el nombre de una ruta.
  def write(preguntas, cuando)
    quitar_viejas(preguntas)
    return self if preguntas.empty?

    nombres = names_for(preguntas.size)
    agregar('VARIABLES', preguntas.map { |p| variable_line(p) })
    agregar('DATOS FIJOS', preguntas.each_with_index.map { |p, i| "#{nombres[i]} (pregunta) = #{p['text']} → guarda en #{p['var']}" })
    usar(nombres, cuando == WELCOME ? START : cuando)
    poner_en_bienvenida(preguntas.first['text']) if cuando == WELCOME
    self
  end

  private

  def stored_questions
    constantes = ContactTrackings::PromptConstants.parse(text).values.select { |c| c[:type] == 'pregunta' }
    variables = ContactTrackings::ConversationVariables.parse(text).variables
    constantes.map do |c|
      var = variables.values.find { |v| v[:name].casecmp?(c[:saves_to].to_s) }
      { 'name' => c[:name], 'text' => c[:value], 'var' => c[:saves_to].to_s, 'options' => Array(var && var[:options]) }
    end
  end

  # Quita las preguntas que había (y sus variables, su uso y su lugar en la bienvenida).
  def quitar_viejas(nuevas)
    lectura = read
    viejas = lectura[:questions]
    quitar_constantes(viejas.pluck('name'))
    quitar_variables((viejas.pluck('var') + nuevas.pluck('var')).compact_blank)
    quitar_uso
    quitar_de_bienvenida(viejas.first['text']) if lectura[:when] == WELCOME
  end

  def in_welcome?(texto)
    rango = section_range(WELCOME_SECTION)
    rango.present? && @lines[(rango[0] + 1)...rango[1]].any? { |l| l.strip == texto.to_s.strip }
  end

  # Al final del texto de la bienvenida, antes de sus {{archivos}}.
  def poner_en_bienvenida(texto)
    rango = section_range(WELCOME_SECTION)
    return @lines.push('', "[#{WELCOME_SECTION}]", texto) if rango.nil?

    ultima = ((rango[0] + 1)...rango[1]).reverse_each.find { |i| @lines[i].present? && !@lines[i].match?(FILE_LINE_RE) }
    @lines.insert((ultima || rango[0]) + 1, texto)
  end

  # Quita la pregunta de la bienvenida; si no queda nada, también la sección.
  def quitar_de_bienvenida(texto)
    quitar_en(WELCOME_SECTION) { |l| l.strip == texto.to_s.strip }
    rango = section_range(WELCOME_SECTION)
    @lines.slice!(rango[0]...rango[1]) if rango && @lines[(rango[0] + 1)...rango[1]].all?(&:blank?)
  end

  def variable_line(pregunta)
    valores = pregunta['options'].presence || ['valor']
    "#{pregunta['var']} = #{valores.join(' | ')}"
  end

  # Q1, Q2… sin chocar con otros datos fijos.
  def names_for(cuantas)
    usados = ContactTrackings::PromptConstants.parse(text).keys.map(&:upcase)
    (1..).lazy.map { |n| "Q#{n}" }.reject { |n| usados.include?(n) }.first(cuantas)
  end

  def where_asked(primera)
    return nil if primera.nil?
    return START if section_range(SECTION)

    scope_line_with("%#{primera}%")&.split(':', 2)&.first&.strip
  end

  def scope_line_with(texto)
    return nil unless scope_range

    @lines[scope_range[0]...scope_range[1]].find { |l| l.include?(texto) }
  end

  def usar(nombres, cuando)
    if cuando.blank? || cuando == START || scope_names.exclude?(cuando)
      agregar(SECTION, [self.class.note(nombres)])
    else
      indice = scope_index(cuando)
      @lines[indice] = "#{@lines[indice].rstrip} #{self.class.note(nombres)}"
    end
  end

  def quitar_constantes(nombres)
    quitar_en('DATOS FIJOS') { |l| (m = l.match(CONST_DECL_RE)) && nombres.include?(m[1]) }
  end

  def quitar_variables(nombres)
    claves = nombres.map(&:upcase)
    quitar_en('VARIABLES') { |l| (m = l.match(VAR_NAME_RE)) && claves.include?(m[1].upcase) }
  end

  def quitar_uso
    rango = section_range(SECTION)
    @lines.slice!(rango[0]...rango[1]) if rango
    return unless scope_range

    (scope_range[0]...scope_range[1]).each { |i| @lines[i] = @lines[i].sub(NOTE_RE, '') }
  end

  def quitar_en(titulo, &)
    rango = section_range(titulo)
    return if rango.nil?

    cuerpo = @lines[(rango[0] + 1)...rango[1]].reject(&)
    @lines[(rango[0] + 1)...rango[1]] = cuerpo
  end

  def agregar(titulo, lineas)
    rango = section_range(titulo)
    return @lines.push('', "[#{titulo}]", *lineas) if rango.nil?

    ultima = (rango[0]...rango[1]).reverse_each.find { |i| @lines[i].present? }
    @lines.insert(ultima + 1, *lineas)
  end

  def section_range(titulo)
    inicio = @lines.index { |l| (m = l.match(HEADER_RE)) && m[1].strip.casecmp?(titulo) }
    return nil if inicio.nil?

    fin = ((inicio + 1)...@lines.size).find { |i| @lines[i].match?(HEADER_RE) } || @lines.size
    [inicio, fin]
  end

  def scope_range
    rango = section_range('ALCANCE POR RAMA')
    rango && [rango[0] + 1, rango[1]]
  end

  def scope_names
    return [] unless scope_range

    @lines[scope_range[0]...scope_range[1]].filter_map { |l| l.split(':', 2).first.to_s.strip.presence if l.include?(':') }
  end

  def scope_index(nombre)
    (scope_range[0]...scope_range[1]).find { |i| @lines[i].split(':', 2).first.to_s.strip.casecmp?(nombre) }
  end
end
