# frozen_string_literal: true

# ================================================================================
# proyecto@adaptar_prompts_publicados (F1) — ESCRIBIR EN EL TEXTO LO QUE SE CONFIGURÓ
# ================================================================================
# La pestaña «Configurar» manda { key => valor } con las llaves de AdaptationInventory y
# esto reescribe el Entrenamiento:
#
#   var:horario              <PENDIENTE: Horario>          → L-V 9 a 18   (todas)
#   google_doc:precios       {{doc:Precios}}               → {{doc:Lista 2026}}
#   google_sheet:catalogo    {{hoja:Catalogo}}             → {{hoja:Catálogo 2026}}
#   knowledge_source:foro x  @buscar_foro(Foro X)          → @buscar_foro(Foro Y)
#   contpaq_support:x        @soporte_contpaq(X)           → @soporte_contpaq(Y)
#   sheet_lookup:gruas       {{hoja_buscar: Gruas | …}}    → {{hoja_buscar: Grúas 2026 | …}}
#   erp_query:sae/saldo      {{consulta:sae/saldo(rfc=?)}} → {{consulta:sae/saldo_cliente(rfc=?)}}
#   attachment:catalogo      {{catalogo}}                  → {{catalogo_2026}}
#   case_type:ventas         @crear_ticket(tipo=Ventas)    → @crear_ticket(tipo=Comercial)
#
# El motor no cambia: lee el mismo texto de siempre, con los nombres de esta cuenta.
#
# Reemplaza el SERVIDOR, con las mismas expresiones del motor, para que el navegador no
# tenga una copia de cada directiva. Solo se toca lo que coincide con la llave: el resto
# del texto queda byte por byte igual. Aplicar dos veces da el mismo texto (la llave vieja
# ya no está).
#
# Un dato que ya se llenó (sin marca) se cambia buscando su valor anterior, que viene en
# `previous` (lo recordado en el agente o en la conversación).
#
# Un valor que rompería la directiva (un «}}» dentro de {{doc:}}, un «)» dentro de
# @buscar_foro) no se aplica: vuelve en `rejected` con el motivo. Un valor vacío deja la
# marca como estaba. Las llaves que no se escriben en el texto (calendar, inbox,
# canned_responses…, y las etiquetas: no se adaptan) vuelven como `not_applicable`: se configuran en otra pantalla.
# Plan: docs/adaptar_prompts_publicados_plan.md
# ================================================================================

class ContactTrackings::Assistant::AdaptationApplier
  Result = Struct.new(:text, :applied, :rejected, keyword_init: true)

  MAX_VALUE = 500
  NAME_VALUE_RE = /\A[a-zA-Z0-9_-]+\z/

  # Lo que no puede ir dentro de cada directiva sin cerrarla antes de tiempo.
  BREAKS = {
    'google_doc' => /[{}\n]/,
    'google_sheet' => /[{}\n]/,
    'sheet_lookup' => /[{}|\n]/,
    'knowledge_source' => /[()\n]/,
    'contpaq_support' => /[()\n]/,
    'case_type' => /[(),\n]/
  }.freeze

  # El valor entero tiene que tener esta forma (un nombre de archivo o de consulta).
  FORMATS = {
    'attachment' => NAME_VALUE_RE,
    'erp_query' => NAME_VALUE_RE
  }.freeze

  # Qué método reescribe cada clase de llave. La que no está no se escribe en el texto.
  BRACED = { 'google_doc' => 'doc', 'google_sheet' => 'hoja' }.freeze
  CALLS = { 'knowledge_source' => 'buscar_foro', 'contpaq_support' => 'soporte_contpaq' }.freeze
  REPLACERS = {
    'var' => :replace_variable,
    'sheet_lookup' => :replace_sheet_lookup,
    'erp_query' => :replace_erp_query,
    'attachment' => :replace_attachment,
    'case_type' => :replace_case_type
  }.freeze

  # previous: lo aplicado antes ({ "var:nombre del negocio" => "Grúas del Sur" }), para
  # cambiar un dato que ya no tiene marca (feat/reemplazo_directo_variables).
  def initialize(text, answers, previous: {})
    @text = text.to_s
    @answers = answers.to_h
    @previous = previous.to_h
    @applied = []
    @rejected = []
  end

  def call
    @answers.each do |key, value|
      kind, name = key.to_s.split(':', 2)
      value = value.to_s.strip
      next if value.empty?

      apply(key.to_s, kind, name.to_s, value)
    end

    Result.new(text: @text, applied: @applied, rejected: @rejected)
  end

  private

  def apply(key, kind, name, value)
    value = normalize(kind, value)
    problem = problem_with(kind, value)
    return @rejected << { key: key, reason: problem } if problem

    replaced = replace(kind, name, value)
    return @rejected << { key: key, reason: 'not_applicable' } if replaced.nil?
    return @rejected << { key: key, reason: 'not_found' } if replaced == @text

    @text = replaced
    @applied << key
  end

  # Un nombre de archivo se escribe sin {{ }}.
  def normalize(kind, value)
    case kind
    when 'attachment' then value.delete_prefix('{{').delete_suffix('}}').strip
    else value
    end
  end

  def problem_with(kind, value)
    return 'too_long' if value.size > MAX_VALUE
    return 'pending' if ContactTrackings::Assistant::PendingMarkers.pending?(value)

    'invalid' unless fits?(kind, value)
  end

  def fits?(kind, value)
    return false if BREAKS[kind]&.match?(value)

    FORMATS[kind].nil? || value.match?(FORMATS[kind])
  end

  # nil = esa clase de llave no se escribe en el texto.
  def replace(kind, name, value)
    return replace_braced(BRACED[kind], name, value) if BRACED.key?(kind)
    return replace_call(CALLS[kind], name, value) if CALLS.key?(kind)

    send(REPLACERS[kind], name, value) if REPLACERS.key?(kind)
  end

  # La llave es "var:<etiqueta en minúsculas>"; la marca puede venir con otras mayúsculas.
  # Sin marca, el valor anterior (si se conoce) pasa al nuevo, solo en la prosa: con la
  # misma protección que al convertir (PublishedPrompts::Variables).
  def replace_variable(name, value)
    con_marca = @text.gsub(ContactTrackings::Assistant::PendingMarkers::RE) do |marca|
      etiqueta = marca[/:\s*([^>]+)>/, 1].to_s.strip.presence || marca
      etiqueta.casecmp?(name) ? value : marca
    end
    anterior = @previous["var:#{name}"].to_s
    return con_marca if con_marca != @text || anterior.blank?

    PublishedPrompts::Variables.replace_in_prose(@text, anterior, value)
  end

  # En bloque y no como cadena de reemplazo: un «\1» en el valor no se interpreta.
  def replace_braced(prefix, name, value)
    @text.gsub(/\{\{\s*#{prefix}\s*:\s*#{Regexp.escape(name)}\s*\}\}/i) { "{{#{prefix}:#{value}}}" }
  end

  def replace_call(directive, name, value)
    @text.gsub(/@#{directive}\(\s*#{Regexp.escape(name)}\s*\)/i) { "@#{directive}(#{value})" }
  end

  # Solo la hoja (lo que va antes del primer |); las columnas quedan como estaban.
  def replace_sheet_lookup(name, value)
    @text.gsub(ContactTrackings::SheetLookup::DIRECTIVE_RE) do |directiva|
      inner = Regexp.last_match(1)
      hoja, resto = inner.split('|', 2)
      next directiva unless hoja.to_s.strip.casecmp?(name)

      espacio = hoja[/\A\s*/]
      "{{hoja_buscar:#{espacio}#{value}#{resto ? " |#{resto}" : ''}}}"
    end
  end

  # La llave es "conexión/consulta" (o solo "consulta"); se cambia la consulta y se
  # conservan la conexión y los parámetros.
  def replace_erp_query(name, value)
    @text.gsub(ExternalDb::ConsultaDirectiveRenderer::DIRECTIVE) do |directiva|
      m = Regexp.last_match
      next directiva unless [m[:conn], m[:name]].compact.join('/').casecmp?(name)

      "{{consulta:#{m[:conn] ? "#{m[:conn]}/" : ''}#{value}#{m[:args] ? "(#{m[:args]})" : ''}}}"
    end
  end

  def replace_attachment(name, value)
    @text.gsub(ContactTrackings::AgentAttachments::DIRECTIVE) do |directiva|
      Regexp.last_match(1).casecmp?(name) ? "{{#{value}}}" : directiva
    end
  end

  # Sin cruzar de línea, como check_ticket_types del comprobador.
  def replace_case_type(name, value)
    @text.gsub(/@crear_ticket\(([^)\n]*)\)/i) do
      args = Regexp.last_match(1)
      nuevos = args.sub(/(tipo\s*=\s*)#{Regexp.escape(name)}(?=\s*(?:,|\z))/i) { "#{Regexp.last_match(1)}#{value}" }
      "@crear_ticket(#{nuevos})"
    end
  end
end
