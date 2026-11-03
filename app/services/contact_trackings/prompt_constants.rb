# frozen_string_literal: true

# ================================================================================
# proyecto@crear_agente_conversando — F2: DATOS FIJOS
# ================================================================================
# Plan: docs/creacion_conversacional_agentes_plan.md §4. Valores que se escriben una
# vez y se citan en cualquier parte del Entrenamiento con %NOMBRE%:
#
#   [DATOS FIJOS]
#   EMPRESA = Kontrolya
#   LIGA_AGENDA (liga) = https://kontrolya.com/agenda-una-demostracion/
#   Q1 (pregunta) = ¿Qué sistemas utilizas hoy? → guarda en SISTEMA
#   CIERRE (texto) = Ahora que ya entendí lo que buscas 👌
#     Puedes agendar aquí 👇 %LIGA_AGENDA%           ← renglones con sangría: siguen el valor
#
#   [BIENVENIDA]
#   Presenta a %EMPRESA% y haz %Q1%.
#
# D1 (decidida 03/11/2026): los SUSTITUYE EL MOTOR antes de mandar el texto al
# modelo, que nunca ve «%Q1%» ni la sección. Se hace en un solo punto:
# ContactTracking#complementary_prompt (el motor, el clasificador, el seco y los
# seguimientos leen el texto por ahí). La plantilla del agente (lo que edita el
# Asistente) guarda siempre las referencias.
#
# Una pregunta con «→ guarda en VARIABLE» se traduce a la regla que el motor ya
# entiende para [VARIABLES] («cuando conteste…, marca SISTEMA=…»).
# Una referencia que no está declarada se deja tal cual: el comprobador la marca en
# rojo (C1), porque el agente la leería literal.
# ================================================================================

module ContactTrackings::PromptConstants
  HEADER_RE = /\A[ \t]*\[[ \t]*(?:DATOS[ \t]+FIJOS|CONSTANTES?)[ \t]*\][ \t]*\z/i
  NAME = '[A-ZÁÉÍÓÚÑ][A-ZÁÉÍÓÚÑ0-9_]*'
  TYPES = %w[texto pregunta liga numero].freeze
  TYPE_ALIASES = { 'número' => 'numero', 'link' => 'liga', 'url' => 'liga', 'question' => 'pregunta',
                   'text' => 'texto', 'number' => 'numero' }.freeze
  DECL_RE = /\A[ \t]*(?:[-*•][ \t]*)?(#{NAME})[ \t]*(?:\([ \t]*(\p{L}+)[ \t]*\))?[ \t]*=[ \t]?(.*?)[ \t]*\z/o
  SAVES_RE = /[ \t]*(?:→|->)[ \t]*guarda(?:r)?[ \t]+en[ \t]+(#{NAME})[ \t]*\z/io
  CONTINUATION_RE = /\A(?: {2,}|\t)(.*)\z/
  REF_RE = /%(#{NAME})%/o
  MAX_PASSES = 3
  SAVES_TITLE = 'PREGUNTAS QUE GUARDAN UN DATO'

  module_function

  # { 'EMPRESA' => { name:, type:, value:, saves_to:, line: }, … } y los renglones de
  # la sección (para quitarla al sustituir).
  # Un valor de varios renglones sigue con sangría (2 espacios o tab); un renglón en
  # blanco entre dos con sangría es un párrafo del mismo valor.
  def parse(text)
    estado = { constantes: {}, actual: nil, blancos: 0 }
    section_lines(text).each { |numero, linea| read_line(estado, numero, linea) }
    estado[:constantes]
  end

  def read_line(estado, numero, linea)
    actual = estado[:actual]
    if linea.strip.empty?
      estado[:blancos] += 1 if actual
    elsif actual && continuation?(linea)
      append(estado, linea[CONTINUATION_RE, 1].rstrip)
    elsif (decl = linea.match(DECL_RE))
      estado[:actual] = declaration(decl, numero)
      estado[:constantes][estado[:actual][:name]] ||= estado[:actual]
      estado[:blancos] = 0
    else
      estado[:actual] = nil
    end
  end

  def append(estado, resto)
    estado[:actual][:value] = [estado[:actual][:value], *Array.new(estado[:blancos], ''), resto].join("\n")
    estado[:blancos] = 0
  end

  def continuation?(linea)
    linea.match?(CONTINUATION_RE) && !linea.match?(DECL_RE)
  end

  def declaration(decl, numero)
    valor = decl[3].to_s
    guarda = valor[SAVES_RE, 1]
    valor = valor.sub(SAVES_RE, '') if guarda
    tipo = decl[2].to_s.downcase
    tipo = TYPE_ALIASES.fetch(tipo, tipo)
    { name: decl[1], type: TYPES.include?(tipo) ? tipo : 'texto', value: valor.strip,
      saves_to: guarda, line: numero }
  end

  # [[número de renglón, renglón], …] dentro de [DATOS FIJOS], sin el rótulo.
  def section_lines(text)
    dentro = false
    text.to_s.split("\n", -1).each_with_index.with_object([]) do |(linea, indice), acc|
      if linea.match?(HEADER_RE)
        dentro = true
      elsif header?(linea)
        dentro = false
      elsif dentro
        acc << [indice + 1, linea]
      end
    end
  end

  def header?(linea) = ContactTrackings::ConversationVariables::Definition.header?(linea)

  def section?(text) = text.to_s.split("\n").any? { |linea| linea.match?(HEADER_RE) }

  # El texto que lee el modelo: sin la sección y con cada %NOMBRE% sustituido.
  def expand(text)
    texto = text.to_s
    # Sin la sección no hay nada que sustituir (un «30%» suelto no es una referencia).
    return texto unless section?(texto)

    constantes = parse(texto)
    sin_seccion = without_section(texto, saves_block(constantes))
    return sin_seccion if constantes.empty?

    valores = resolved_values(constantes)
    sin_seccion.gsub(REF_RE) { |ref| valores.fetch(Regexp.last_match(1), ref) }
  end

  # Un valor puede citar a otro (CIERRE cita %LIGA_AGENDA%): se resuelven entre ellos
  # unas pocas vueltas; una referencia circular se queda como está.
  def resolved_values(constantes)
    # Una pregunta se cita entre «»: «haz %Q1%» → «haz «¿Qué sistemas utilizas?»».
    valores = constantes.transform_values { |c| c[:type] == 'pregunta' ? "«#{c[:value]}»" : c[:value] }
    MAX_PASSES.times do
      valores = valores.transform_values { |v| v.gsub(REF_RE) { |ref| valores.fetch(Regexp.last_match(1), ref) } }
    end
    valores
  end

  def without_section(texto, reemplazo)
    salida = []
    dentro = false
    texto.split("\n", -1).each do |linea|
      if linea.match?(HEADER_RE)
        dentro = true
        salida.concat(reemplazo) if reemplazo.any?
      elsif dentro && header?(linea)
        dentro = false
        salida << linea
      elsif !dentro
        salida << linea
      end
    end
    salida.join("\n").gsub(/\n{3,}/, "\n\n")
  end

  # Las preguntas que guardan su respuesta en una variable, como reglas del motor.
  def saves_block(constantes)
    reglas = constantes.values.select { |c| c[:type] == 'pregunta' && c[:saves_to].present? }.map do |c|
      "- Cuando el cliente conteste «#{c[:value]}», marca #{c[:saves_to]}=<lo que contestó>."
    end
    reglas.any? ? ["[#{SAVES_TITLE}]", *reglas, ''] : []
  end
end
