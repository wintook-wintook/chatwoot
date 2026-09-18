# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — LAS RAMAS COMO CAMPOS
# ================================================================================
# El bloque de ramas del formulario (ver TrainingStructure) era una caja de texto con
# las líneas `@ruta` crudas: la parte del Entrenamiento con la gramática más estricta
# —y la que más se rompe— era la única que no tenía formulario.
#
# Acá cada línea se parte en los campos que edita el formulario:
#
#   @ruta(comercial #precios: cuanto cuesta, precios): {{hoja:Precios}} -> @crear_ticket(tipo=Comercial)
#    │       │        │              │                        │                     │
#    │     nombre  etiqueta      frases del cliente         fuente             escalamiento
#
# SE USA EL PARSER REAL: los patrones son los de RouteMap, los mismos que lee el motor.
# Una copia se desincronizaría en silencio, que es justo el defecto que el comprobador
# existe para cazar.
#
# INVARIANTE (la de TrainingStructure): cada entrada guarda su línea original en `raw`
# y se devuelve tal cual mientras sus campos no cambien. Así abrir un agente en el
# formulario y guardarlo sin tocar nada no cambia ni un carácter — ni el espaciado, ni
# un `=>` en vez de `->`, ni una línea que el parser no reconoce (que se conserva como
# `other` en su lugar, en vez de desaparecer).
# ================================================================================

module ContactTrackings::TrainingRoutes
  Map = ContactTrackings::RouteMap
  KINDS = %w[route default other].freeze
  # `escalation` es la cadena tal cual; `action`, `case_type` y `priority` son la misma
  # cosa partida en los tres selectores del formulario. Si vienen, mandan ellos.
  FIELDS = %w[kind name tag description source escalation action case_type priority raw].freeze
  TICKET_RE = /\A@crear_ticket(?:\(([^)]*)\))?\z/i
  # Tope por bloque: un Entrenamiento real llega a 9 ramas; esto es contra un payload
  # armado a mano, no contra un agente grande.
  MAX_LINES = 200

  module_function

  # ── texto → entradas ────────────────────────────────────────────────────────
  def parse(text)
    text.to_s.split("\n", -1).map { |line| entry(line) }
  end

  def entry(line)
    if (m = line.match(Map::LINE_RE))
      route_entry(m, line)
    elsif (m = line.match(Map::DEFAULT_RE))
      { 'kind' => 'default', 'name' => m[1].downcase, 'raw' => line }
    else
      { 'kind' => 'other', 'raw' => line }
    end
  end

  def route_entry(match, line)
    source, escalation = match[4].to_s.strip.split(Map::ARROW_RE, 2).map { |part| part.to_s.strip }
    { 'kind' => 'route',
      'name' => match[1].to_s.downcase,
      'tag' => match[2].to_s.downcase,
      'description' => match[3].to_s.strip,
      # El guion "sin fuente" es una marca, no una fuente: en el formulario es el campo vacío.
      'source' => Map::NO_SOURCE.include?(source) ? '' : source.to_s,
      'escalation' => escalation.to_s,
      'raw' => line }.merge(escalation_fields(escalation.to_s))
  end

  # Abrir un caso se edita en tres campos, porque son tres decisiones distintas: que
  # abra caso, de qué tipo y con qué prioridad. El resto de las acciones no llevan
  # parámetros, así que la acción es la cadena entera.
  def escalation_fields(escalation)
    vacio = { 'action' => '', 'case_type' => '', 'priority' => '' }
    return vacio if escalation.blank?
    return vacio.merge('action' => escalation) unless (m = escalation.strip.match(TICKET_RE))

    partes = m[1].to_s.split(',').filter_map { |par| par.split('=', 2).map(&:strip) if par.include?('=') }
    params = partes.to_h.transform_keys(&:downcase)
    { 'action' => '@crear_ticket', 'case_type' => params['tipo'].to_s, 'priority' => params['prioridad'].to_s }
  end

  # ── entradas → texto ────────────────────────────────────────────────────────
  def compose(entries)
    Array(entries).first(MAX_LINES).map { |entrada| line_for(entrada.to_h.stringify_keys) }.join("\n")
  end

  # La línea original mientras siga diciendo lo mismo; si no, una escrita de cero.
  def line_for(entrada)
    raw = entrada['raw'].to_s
    return raw if raw.present? && same_fields?(entry(raw), entrada)

    case entrada['kind']
    when 'route' then route_line(entrada)
    when 'default' then default_line(entrada)
    else raw
    end
  end

  def same_fields?(desde_raw, entrada)
    %w[kind name tag description source].all? { |campo| desde_raw[campo].to_s == entrada[campo].to_s } &&
      escalation_for(desde_raw) == escalation_for(entrada)
  end

  def route_line(entrada)
    nombre = clean(entrada['name']).downcase.gsub(/[^a-z0-9_-]/, '')
    return '' if nombre.blank?

    etiqueta = clean(entrada['tag']).downcase.gsub(/[^a-z0-9_]/, '')
    # Los paréntesis son de la gramática: el de cierre corta la descripción para el
    # parser, y uno de apertura suelto deja la línea ilegible. Se van los dos.
    descripcion = clean(entrada['description']).delete('()')
    cabeza = ["@ruta(#{nombre}", etiqueta.present? ? " ##{etiqueta}" : nil].compact.join
    "#{cabeza}#{descripcion.present? ? ": #{descripcion}" : ''}): #{body_for(entrada)}"
  end

  # Sin fuente va el guion: "esta rama no consulta nada" tiene que estar escrito, porque
  # dejarlo vacío deja la línea sin lado derecho y el motor no la lee.
  def body_for(entrada)
    fuente = clean(entrada['source']).presence || '-'
    escalamiento = escalation_for(entrada)
    escalamiento.present? ? "#{fuente} -> #{escalamiento}" : fuente
  end

  # La cadena del escalamiento: de los tres campos si el formulario los mandó, y si no
  # de la cadena tal como estaba.
  def escalation_for(entrada)
    return clean(entrada['escalation']) unless entrada.key?('action')

    accion = clean(entrada['action'])
    return accion unless accion.match?(TICKET_RE)

    params = [['tipo', clean(entrada['case_type'])], ['prioridad', clean(entrada['priority'])]]
             .filter_map { |clave, valor| "#{clave}=#{valor}" if valor.present? }
    params.any? ? "@crear_ticket(#{params.join(', ')})" : '@crear_ticket'
  end

  def default_line(entrada)
    nombre = clean(entrada['name']).downcase.gsub(/[^a-z0-9_-]/, '')
    nombre.present? ? "@ruta_por_defecto: #{nombre}" : ''
  end

  # Un salto de línea o un tabulador partirían la línea en dos y la rama dejaría de
  # existir: lo que se escriba en un campo queda en una sola línea.
  def clean(value)
    value.to_s.tr("\n\r\t", '   ').squeeze(' ').strip
  end

  # Lo que llega del formulario: solo las claves conocidas y solo si el tipo es conocido.
  def sanitize(lines)
    Array(lines).first(MAX_LINES).filter_map do |linea|
      datos = linea.to_h.stringify_keys.slice(*FIELDS)
      next unless KINDS.include?(datos['kind'])

      datos.transform_values { |valor| valor.to_s.first(2000) }
    end
  end
end
