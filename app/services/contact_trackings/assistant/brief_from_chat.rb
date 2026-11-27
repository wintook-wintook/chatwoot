# frozen_string_literal: true

# ================================================================================
# proyecto@crear_agente_conversando — F3: LO QUE LA CONVERSACIÓN YA DECIDIÓ, AL REDACTOR
# ================================================================================
# Plan: docs/creacion_conversacional_agentes_plan.md §6 y D10. Cuando las instrucciones
# salieron de la conversación (DraftingChat), el encargo está ligado a ella y su
# proposal ya trae:
#   objective / ai_context      la Definición                  → manda sobre la ficha
#   variables / datos_fijos     el texto de [VARIABLES] y [DATOS FIJOS]
#   boceto                      las rutas ya probadas
#
# Al redactor (BriefComposer) se le dan para copiar, no para redactar: las secciones
# tal cual, con la orden de citar %Q1% en vez de copiar la pregunta, y el boceto como
# base de las rutas (así los nombres coinciden con las pruebas que se llevan a la pila,
# ver DraftingTestCarrier).
#
# Después la cobertura (BriefCoverage) las vuelve a poner EXACTAS (#apply): el modelo
# de una sola vez reescribe lo que se le da (medido con las reglas, ver BriefCoverage),
# y estas dos secciones son configuración, no prosa.
# ================================================================================

class ContactTrackings::Assistant::BriefFromChat
  SECTIONS = { 'VARIABLES' => /\A[ \t]*\[[ \t]*VARIABLES[ \t]*\][ \t]*\z/i,
               'DATOS FIJOS' => ContactTrackings::PromptConstants::HEADER_RE }.freeze
  FIELDS = { 'VARIABLES' => 'variables', 'DATOS FIJOS' => 'datos_fijos' }.freeze
  SECTION_RE = ContactTrackings::Assistant::DraftPieces::SECTION_RE

  def initialize(brief)
    @proposal = brief&.tracking_assistant_session&.proposal.to_h
  end

  def objective = @proposal['objective'].to_s.strip.presence

  def ai_context = @proposal['ai_context'].to_s.strip.presence

  # { 'VARIABLES' => cuerpo, 'DATOS FIJOS' => cuerpo }, solo las que hay.
  def sections
    FIELDS.transform_values { |campo| @proposal[campo].to_s.strip }.compact_blank
  end

  def routes = ContactTrackings::Assistant::DraftingFields.routes_text(@proposal['boceto'])

  # Lo que se suma al mensaje del redactor; nil si la conversación no decidió nada de esto.
  def message_block
    [sections_block, routes_block].compact.join("\n\n").presence
  end

  # Las líneas del Entrenamiento con cada sección decidida EXACTA: si la escribió, se
  # reemplaza su cuerpo; si no, se agrega antes de la primera sección.
  def apply(lineas)
    sections.reduce(lineas.dup) { |actuales, (titulo, cuerpo)| put(actuales, titulo, cuerpo) }
  end

  private

  def sections_block
    return nil if sections.empty?

    texto = sections.map { |titulo, cuerpo| "[#{titulo}]\n#{cuerpo}" }.join("\n\n")
    'SECCIONES YA DECIDIDAS EN LA CONVERSACIÓN: cópialas al Entrenamiento TAL CUAL, sin cambiar una letra, ' \
      "antes de las demás secciones:\n\n#{texto}\n\nDonde una ruta o una regla haga una de esas preguntas o " \
      'use uno de esos datos, escribe su %NOMBRE% (ej. «haz %Q1%», «la liga es %LIGA_AGENDA%») en vez de copiar el texto.'
  end

  def routes_block
    return nil if routes.blank?

    'RUTAS YA PROBADAS EN LA CONVERSACIÓN: son la base de las rutas del Entrenamiento. Conserva sus nombres, ' \
      "sus frases y su fuente; agrégales lo que pidan las instrucciones (etiqueta, acción, más frases):\n\n#{routes}"
  end

  def put(lineas, titulo, cuerpo)
    inicio = lineas.index { |l| l.match?(SECTIONS[titulo]) }
    nuevas = cuerpo.split("\n")
    return insert(lineas, titulo, nuevas) if inicio.nil?

    fin = section_end(lineas, inicio)
    lineas[0..inicio] + nuevas + [''] + lineas[fin..].to_a.drop_while(&:blank?)
  end

  # Antes de la primera sección; los Datos fijos, después de las Variables.
  def insert(lineas, titulo, nuevas)
    variables = titulo == 'DATOS FIJOS' && lineas.index { |l| l.match?(SECTIONS['VARIABLES']) }
    donde = variables ? section_end(lineas, variables) : lineas.index { |l| l.match?(SECTION_RE) } || lineas.size
    lineas[0...donde] + ["[#{titulo}]", *nuevas, ''] + lineas[donde..].to_a
  end

  # El renglón donde empieza lo siguiente: otra sección o una línea de ruta.
  def section_end(lineas, inicio)
    siguiente = lineas[(inicio + 1)..].index { |l| l.match?(SECTION_RE) || l.lstrip.start_with?('@ruta') }
    siguiente ? inicio + 1 + siguiente : lineas.size
  end
end
