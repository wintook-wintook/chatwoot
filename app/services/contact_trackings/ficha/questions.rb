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
#
# read: lo que ya tiene un Entrenamiento. write: reemplaza SOLO las preguntas (los demás
# datos fijos y variables se quedan). Mismos patrones que PromptConstants y Variables.
# ================================================================================

class ContactTrackings::Ficha::Questions
  START = 'start'
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
      h = pregunta.to_h.stringify_keys
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
    constantes = ContactTrackings::PromptConstants.parse(text).values.select { |c| c[:type] == 'pregunta' }
    variables = ContactTrackings::ConversationVariables.parse(text).variables
    preguntas = constantes.map do |c|
      var = variables.values.find { |v| v[:name].casecmp?(c[:saves_to].to_s) }
      { 'name' => c[:name], 'text' => c[:value], 'var' => c[:saves_to].to_s, 'options' => Array(var && var[:options]) }
    end
    { questions: preguntas, when: where_asked(preguntas.first&.dig('name')) }
  end

  # cuando: START o el nombre de una ruta.
  def write(preguntas, cuando)
    viejas = read[:questions]
    quitar_constantes(viejas.pluck('name'))
    quitar_variables((viejas.pluck('var') + preguntas.pluck('var')).compact_blank)
    quitar_uso
    return self if preguntas.empty?

    nombres = names_for(preguntas.size)
    agregar('VARIABLES', preguntas.map { |p| variable_line(p) })
    agregar('DATOS FIJOS', preguntas.each_with_index.map { |p, i| "#{nombres[i]} (pregunta) = #{p['text']} → guarda en #{p['var']}" })
    usar(nombres, cuando)
    self
  end

  private

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
