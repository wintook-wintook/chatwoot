# frozen_string_literal: true

# ================================================================================
# proyecto@solicitudes — SEPARAR UN MENSAJE EN SERVICIOS (pieza 5, F1, 26/09/2026)
# ================================================================================
# «1 grúa cap. 60 tons, 01 tracto con plana de 12 mts, 01 camión con grúa tipo hiab» son TRES
# servicios. Una llamada a la IA con salida JSON; las reglas salen del corpus de SSUSA
# (docs/solicitudes_multiservicio_plan.md §3).
#
# La IA NO calcula fechas ni duraciones: devuelve lo que escribió el cliente («mañana»,
# «el lunes 01 de junio», «jornada de 16 horas») y lo resuelve Ruby después, con lo que ya
# existe (calculate_reschedule_datetime, AmbiguousDate, CalendarOptions.duration_in).
#
# nil = no se pudo (sin clave, error de la API, JSON roto): el motor sigue sin @solicitudes.
# ================================================================================

class ContactTrackings::ServiceRequests::Extractor
  Service = Struct.new(:ref, :label, :equipment_type, :capacity_t, :stops, :date_text, :time_text,
                       :duration_text, :cargo, :weight_t, :dimensions, :folios, :site_contact,
                       :mode, :notes, keyword_init: true)

  MAX_TEXT = 6000

  def initialize(account:, text:, tracking: nil, context: nil)
    @account = account
    @text = text.to_s.strip
    @tracking = tracking
    @context = context.to_s.strip
  end

  def call
    return [] if @text.blank?

    api_key = @account.hooks.find_by(app_id: 'openai', status: 'enabled')&.settings&.dig('api_key').presence
    return nil if api_key.blank?

    servicios = JSON.parse(ask(api_key)).fetch('servicios', [])
    split_delivery_and_pickup(servicios.each_with_index.map { |raw, i| build(raw, i) })
  rescue StandardError => e
    Rails.logger.warn "[ServiceRequests::Extractor] ⚠️ #{e.message}"
    nil
  end

  private

  def build(raw, index)
    Service.new(**what(raw, index), **when_and_where(raw), **details(raw))
  end

  def what(raw, index)
    { ref: (raw['ref'].presence || (index + 1)).to_s, label: raw['etiqueta'].to_s.strip.presence,
      equipment_type: raw.dig('equipo', 'tipo').to_s.strip.presence, capacity_t: number(raw.dig('equipo', 'capacidad_t')) }
  end

  def when_and_where(raw)
    { stops: Array(raw['paradas']).filter_map { |p| p.slice('tipo', 'lugar') if p.is_a?(Hash) && p['lugar'].present? },
      date_text: raw['fecha'].presence, time_text: raw['hora'].presence, duration_text: raw['duracion'].presence }
  end

  def details(raw)
    { cargo: raw['carga'].presence, weight_t: number(raw['peso_t']), dimensions: raw['medidas'].presence,
      folios: Array(raw['folios']).map(&:to_s).compact_blank, site_contact: raw['responsable_sitio'].presence,
      mode: raw['modalidad'].presence, notes: raw['notas'].presence }
  end

  # «Entrega y recolección (Carmen – Villahermosa – Carmen)»: la IA insiste en un viaje redondo,
  # pero son dos movimientos en fechas distintas (al empezar y al terminar la renta). Sin IA:
  # si el mensaje lo dice y un servicio vuelve a su origen, se parte en dos.
  PICKUP_RE = /entrega\s+y\s+recolecci[oó]n/i

  def split_delivery_and_pickup(servicios)
    return servicios unless @text.match?(PICKUP_RE)

    partidos = servicios.flat_map { |servicio| round_trip?(servicio) ? delivery_and_pickup(servicio) : [servicio] }
    partidos.each_with_index { |servicio, i| servicio.ref = (i + 1).to_s }
  end

  def round_trip?(servicio)
    paradas = servicio.stops
    paradas.size >= 3 && paradas.first['lugar'].casecmp?(paradas.last['lugar'])
  end

  def delivery_and_pickup(servicio)
    ida = servicio.stops[0..-2]
    entrega = servicio.dup
    entrega.label = "#{servicio.label} — entrega"
    entrega.stops = ida
    recoleccion = servicio.dup
    recoleccion.label = "#{servicio.label} — recolección"
    recoleccion.stops = retyped(ida.reverse)
    recoleccion.date_text = nil
    [entrega, recoleccion]
  end

  # Al invertir la ruta, el primero es el origen y el último el destino.
  def retyped(paradas)
    ultima = paradas.size - 1
    paradas.each_with_index.map do |parada, i|
      parada.merge('tipo' => { 0 => 'origen', ultima => 'destino' }.fetch(i, 'parada'))
    end
  end

  def number(value)
    value.nil? || value == '' ? nil : value.to_s.tr(',', '.').to_f
  end

  def ask(api_key)
    response = HTTParty.post(
      'https://api.openai.com/v1/chat/completions',
      headers: { 'Authorization' => "Bearer #{api_key}", 'Content-Type' => 'application/json' },
      body: {
        model: ContactTrackings::EngineConfig.model_for_tracking(@tracking, :service_requests),
        messages: [{ role: 'system', content: RULES }, { role: 'user', content: user_prompt }],
        max_tokens: ContactTrackings::EngineConfig.max_tokens_for(:service_requests),
        temperature: 0, response_format: { type: 'json_object' }
      }.to_json,
      timeout: 40
    )
    raise "OpenAI #{response.code}" unless response.success?

    response.parsed_response.dig('choices', 0, 'message', 'content').to_s
  end

  def user_prompt
    contexto = @context.present? ? "Mensajes anteriores de la conversación:\n#{@context.truncate(2000)}\n\n" : ''
    "#{contexto}Mensaje actual del cliente:\n\"\"\"\n#{@text.truncate(MAX_TEXT)}\n\"\"\""
  end

  RULES = <<~RULES
    Eres el capturista de una empresa de grúas, hiab, planas y transporte. Del mensaje del
    cliente, saca la LISTA DE SERVICIOS que pide. No inventes nada: si un dato no está, null.

    Cuándo es UN servicio y cuándo son VARIOS:
    - Un servicio por cada equipo pedido: «1 grúa 60 t, 01 tracto con plana 12 m, 01 camión con
      hiab» son 3.
    - La CANTIDAD cuenta: «02 camiones con hiab» son 2 servicios (repite el servicio, uno por
      unidad, con ref distinta). «2 unidades, Hiab 14 t y Hiab 12 t» son 2.
    - Cada «SOLICITUD 01», «SOLICITUD 02»… es un servicio.
    - «Cotizar por separado» dos equipos = 2 servicios.
    - «Entrega y recolección» = SIEMPRE 2 servicios aunque la ruta sea ida y vuelta: 1) la
      entrega (origen → destino) y 2) la recolección (destino → origen), en fechas distintas.
    - «Consolidar» tramos, o un «viaje redondo» / «y retorno» en el MISMO viaje, = UN servicio con
      varias paradas.
    - Otra carga en el mismo traslado («adicionalmente», «también», «además» mover X por la
      misma ruta) = el MISMO servicio: suma la carga, no crees otro. Ejemplo: «envío de un magneto
      de la base WTF a Carmen. Adicionalmente programar tres tramos de 20"» → UN servicio, carga
      «magneto + 3 tramos de 20"».
    - Un servicio extra de otro equipo (p. ej. «horas de hiab para carga y descarga») es otro
      servicio.
    - Si el mensaje no pide ningún servicio (saludo, pregunta general), la lista va vacía.

    Datos de cada servicio:
    - etiqueta: SIEMPRE, nombre corto para el cliente («Grúa 60 t», «Hiab 12 t», «Plana 12 m»,
      «Flete plataforma Haulotte HA20»).
    - equipo.tipo: UNA sola palabra de esta lista: grúa, hiab, plana, cama baja, low boy, torton,
      rabón, pick up, camión, tracto, quinta, contenedor, plataforma de elevación, otro.
      «camión con grúa tipo hiab» = hiab; «tracto con plana de 12 mts» = plana; «unidad
      ligera» = pick up. equipo.capacidad_t: solo si el cliente la dijo (toneladas).
    - paradas: en orden. «Presentarse en» / «origen» / «carga en» = origen. «Entregar en» /
      «destino» = destino. Un viaje redondo repite el origen al final.
    - fecha: SOLO el día, copiado como lo escribió el cliente («mañana», «el lunes 01 de junio»,
      «31 de mayo 2026»). Si dice «mañana» y además la fecha escrita, usa la fecha escrita.
      NO calcules fechas.
    - hora: SOLO la hora de inicio («08:00 am», «03:00 hrs», «6:00 pm»).
    - duracion: el texto tal cual («1 hora», «jornada de 16 horas», «6 meses», «renta mensual»).
      Si viene un rango de horas («6:00 pm - 12:00 am»), hora = el inicio y duracion = el rango.
    - folios: todos los identificadores del cliente (NAV…, LOAD…, OCI…, DMX-…).
    - Si un dato se corrige en el mismo hilo, usa el ÚLTIMO.

    Responde SOLO este JSON:
    {"servicios": [{"ref": "1", "etiqueta": "", "equipo": {"tipo": "", "capacidad_t": null},
      "paradas": [{"tipo": "origen|destino|parada", "lugar": ""}], "fecha": null, "hora": null,
      "duracion": null, "carga": null, "peso_t": null, "medidas": null, "folios": [],
      "responsable_sitio": null, "modalidad": null, "notas": null}]}
  RULES
  private_constant :RULES
end
