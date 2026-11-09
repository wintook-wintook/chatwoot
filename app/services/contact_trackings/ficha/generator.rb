# frozen_string_literal: true

# ================================================================================
# feat/ficha_agente_ia — EL AGENTE EN UNOS CUANTOS CLICS
# ================================================================================
# Plan: docs/ficha_agente_ia_plan.md §7. Con lo marcado en la ficha y las ofertas que la
# persona dejó prendidas, escribe el Entrenamiento COMPLETO sin IA:
#
#   @ruta(consultar_precios #precios: pregunta por servicio, zona, precio): {{hoja_buscar: …}}
#   @ruta(agendar_cita #agendar: quiere agendar, cambiar o confirmar una cita): - -> @agendar_calendar
#   @ruta_por_defecto: consultar_precios
#
#   [ROL] [ALCANCE POR RAMA] [FIDELIDAD] [ETIQUETAS] [ESTILO] [PROHIBIDO] (+ [ARCHIVOS])
#
# y lo pasa por el mismo comprobador del editor (ValidatorService). Lo que sale es un
# punto de partida que ya funciona: después se afina en el chat o en el editor.
#
# Cuidado con las palabras: en [ALCANCE POR RAMA] «agenda/cita» y «abre un ticket» solo
# van en la ruta que tiene esa acción (PromiseChecks), y nada promete «te confirmo en un
# momento» sin negarlo.
# ================================================================================

class ContactTrackings::Ficha::Generator
  TONES = {
    'cercano' => 'Hablo de tú, en español de México, cálido y cercano. Respuestas cortas y claras, de máximo 4 líneas.',
    'profesional' => 'Hablo de tú, en español de México, con un tono profesional y amable. Respuestas cortas y claras, ' \
                     'de máximo 4 líneas, sin emojis.'
  }.freeze
  MAX_OBJECTIVE = 500
  MAX_CONTEXT = 800

  # offers: ContactTrackings::Ficha::Offers#call (solo las que quedaron prendidas)
  # options: objective:, business:, tone: ('cercano' | 'profesional')
  def initialize(account:, name:, offers:, **options)
    @account = account
    @name = name.to_s.squish.presence || 'tu negocio'
    @offers = offers
    @objective = options[:objective].to_s.squish
    @business = options[:business].to_s.strip
    @tone = TONES.key?(options[:tone].to_s) ? options[:tone].to_s : 'cercano'
  end

  def call
    prompt = text
    validacion = ContactTrackings::Assistant::ValidatorService.new(prompt, account: @account).call
    { prompt: prompt, objective: objective, ai_context: @business.first(MAX_CONTEXT),
      routes: routes.map { |o| o[:route].slice(:name, :tag, :description).merge(label: o[:label], key: o[:key], kind: o[:kind]) },
      validation: validacion.slice(:blocking, :degrading, :cosmetic, :valid) }
  end

  # Por tipo de tarea, no oferta por oferta: corto aunque se marquen muchas cosas.
  TASKS = [
    [%w[sheet doc articles canned forum contpaq discourse erp], 'contestar sus dudas con información exacta'],
    [%w[calendar], 'agendar sus citas'],
    [%w[case_type], 'levantar sus solicitudes para que una persona las atienda'],
    [%w[file], 'mandarles los archivos que pidan']
  ].freeze

  def objective
    return @objective.truncate(MAX_OBJECTIVE, omission: '…') if @objective.length >= 5

    tipos = @offers.pluck(:kind)
    tareas = TASKS.filter_map { |kinds, texto| texto if tipos.intersect?(kinds) }
    tareas = ['contestar sus dudas'] if tareas.empty?
    lista = tareas.size > 1 ? "#{tareas[0..-2].join(', ')} y #{tareas.last}" : tareas.first
    "Atender a los clientes de #{@name}: #{lista}."
  end

  private

  def routes = @offers.select { |o| o[:route] }

  def files = @offers.select { |o| o[:kind] == 'file' }

  def text
    [route_block, rol, alcance, fidelidad, etiquetas, archivos, estilo, prohibido].compact.join("\n\n")
  end

  def route_block
    lineas = routes.map { |o| o[:route][:line] }
    lineas << "@ruta_por_defecto: #{default_route[:route][:name]}" if default_route
    lineas.join("\n")
  end

  # Por defecto, la primera que CONTESTA (no la de agendar ni la de ticket).
  def default_route
    routes.find { |o| %w[calendar case_type].exclude?(o[:kind]) } || routes.first
  end

  def rol
    "[ROL]\nSoy el asistente virtual de #{@name}. #{objective}"
  end

  def alcance
    lineas = routes.map { |o| "#{o[:route][:name]}: #{scope_for(o)}" }
    "[ALCANCE POR RAMA]\n#{lineas.join("\n")}"
  end

  # Qué hace cada ruta, en primera persona. «agenda/cita» y «abre un ticket» solo en la
  # ruta que tiene esa acción (PromiseChecks). %<nombre>s = el recurso.
  SCOPES = {
    'sheet' => 'Busco en la hoja «%<nombre>s» el dato que pide y contesto exacto, con lo que dice la hoja.',
    'doc' => 'Contesto con lo que dice el documento «%<nombre>s».',
    'articles' => 'Contesto con los artículos de ayuda.',
    'canned' => 'Contesto con las respuestas predefinidas de %<nombre>s.',
    'forum' => 'Busco la solución en el foro y la explico paso a paso.',
    'discourse' => 'Busco la solución en el foro y la explico paso a paso.',
    'contpaq' => 'Busco la solución de soporte de CONTPAQi y la explico paso a paso.',
    'erp' => 'Consulto en el ERP y contesto con el resultado exacto.',
    'calendar' => 'Agendo la cita: ofrezco los horarios libres y confirmo el día y la hora con el cliente.',
    'case_type' => 'Abro un ticket «%<nombre>s» con los datos que pide y le digo al cliente que una persona lo atenderá.'
  }.freeze

  def scope_for(oferta)
    format(SCOPES.fetch(oferta[:kind], 'Contesto con lo que encuentro.'), nombre: oferta[:name])
  end

  def fidelidad
    "[FIDELIDAD]\nContesto solo con lo que encuentro en mis fuentes. Si no encuentro el dato, lo digo con " \
      'honestidad y ofrezco otra forma de ayudar; no invento precios, fechas ni datos.'
  end

  def etiquetas
    lineas = routes.map { |o| "##{o[:route][:tag]} = cuando el cliente #{o[:route][:description]}." }
    "[ETIQUETAS]\n#{lineas.join("\n")}"
  end

  # El modelo escribe {{nombre}} en su respuesta y el motor manda el archivo.
  def archivos
    return nil if files.empty?

    lineas = files.map { |o| "Si el cliente pide #{o[:topic]}, escribo {{#{o[:name]}}} en mi respuesta para mandarle el archivo." }
    "[ARCHIVOS]\n#{lineas.join("\n")}"
  end

  def estilo = "[ESTILO]\n#{TONES[@tone]}"

  def prohibido
    "[PROHIBIDO]\nNunca invento precios, horarios ni datos que no estén en mis fuentes. Nunca prometo hacer algo " \
      'después ni digo que lo estoy revisando: contesto con lo que tengo en ese momento.'
  end
end
