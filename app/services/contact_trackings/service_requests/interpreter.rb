# frozen_string_literal: true

# ================================================================================
# proyecto@solicitudes — LEER LA RESPUESTA A LAS OPCIONES (observaciones SSUSA 22/10, F1)
# ================================================================================
# «Adelante con el horario» no decía «1A» ni empezaba con «sí»: el bot repetía la propuesta.
# Aquí la IA lee la respuesta frente a las opciones abiertas y dice qué quiso el cliente:
#   elegir    «sí», «adelante», «va» (general: la primera de cada servicio)
#             «la de las 14», «la TP-73», «el 2 a las 16» (códigos concretos)
#   ambigua   «sí pero más tarde», «el otro» → una pregunta con las opciones
#   rechazo   «ninguna», «no me sirve» → pedir otro día u hora
#   otra      pregunta, dato nuevo, hora que no está en las opciones → el motor sigue
# Ruby valida los códigos: la IA no puede apartar algo que no se ofreció.
#
# nil = no se pudo (sin clave, error de la API, JSON roto): Choice usa sus patrones.
# ================================================================================

class ContactTrackings::ServiceRequests::Interpreter
  Result = Struct.new(:action, :general, :codes, keyword_init: true)

  ACTIONS = %w[elegir ambigua rechazo otra].freeze

  # cases: los casos con oferta, en el orden en que los ve el cliente → [[número, caso], …]
  def initialize(account:, text:, cases:, timezone:, tracking: nil)
    @account = account
    @text = text.to_s.strip
    @cases = cases
    @timezone = timezone
    @tracking = tracking
  end

  def call
    return nil if @text.blank? || @cases.empty?

    api_key = @account.hooks.find_by(app_id: 'openai', status: 'enabled')&.settings&.dig('api_key').presence
    return nil if api_key.blank?

    build(JSON.parse(ask(api_key)))
  rescue StandardError => e
    Rails.logger.warn "[ServiceRequests::Interpreter] ⚠️ #{e.message}"
    nil
  end

  private

  def build(raw)
    accion = raw['accion'].to_s
    return nil unless ACTIONS.include?(accion)

    codigos = Array(raw['codigos']).map { |c| c.to_s.strip.upcase } & valid_codes
    general = raw['general'] == true && codigos.empty?
    # «elegir» sin nada que apartar no sirve: mejor preguntar que repetir la propuesta.
    accion = 'ambigua' if accion == 'elegir' && !general && codigos.empty?
    Result.new(action: accion.to_sym, general: general, codes: codigos)
  end

  def valid_codes
    @cases.flat_map { |_, caso| caso.metadata['oferta'].map { |oferta| oferta['code'].upcase } }
  end

  def ask(api_key)
    response = HTTParty.post(
      'https://api.openai.com/v1/chat/completions',
      headers: { 'Authorization' => "Bearer #{api_key}", 'Content-Type' => 'application/json' },
      body: {
        model: ContactTrackings::EngineConfig.model_for_tracking(@tracking, :service_requests),
        messages: [{ role: 'system', content: RULES }, { role: 'user', content: user_prompt }],
        max_tokens: 200, temperature: 0, response_format: { type: 'json_object' }
      }.to_json,
      timeout: 20
    )
    raise "OpenAI #{response.code}" unless response.success?

    response.parsed_response.dig('choices', 0, 'message', 'content').to_s
  end

  def user_prompt
    "Opciones que se le ofrecieron:\n#{offers_text}\n\nRespuesta del cliente:\n\"\"\"\n#{@text.truncate(1000)}\n\"\"\""
  end

  def offers_text
    @cases.map do |numero, caso|
      opciones = caso.metadata['oferta'].map { |oferta| "  #{oferta['code']}: #{option_text(oferta)}" }
      "Servicio #{numero} — #{caso.metadata.dig('servicio', 'label') || caso.title}#{asked_text(caso)}\n#{opciones.join("\n")}"
    end.join("\n")
  end

  def option_text(oferta)
    unidad = oferta['calendar_name'].present? ? " (unidad #{oferta['calendar_name']})" : ''
    return "#{ContactTrackings::ServiceRequests::Turn.period_text(oferta, @timezone)}#{unidad}" if oferta['all_day']

    inicio = Time.zone.parse(oferta['slot']).in_time_zone(@timezone)
    fin = Time.zone.parse(oferta['end_time']).in_time_zone(@timezone)
    "#{ContactTrackings::ServiceRequests::Turn::DAYS[inicio.wday]} #{inicio.day} " \
      "#{ContactTrackings::ServiceRequests::Turn::MONTHS[inicio.month - 1]} " \
      "#{inicio.strftime('%H:%M')}–#{fin.strftime('%H:%M')}#{unidad}"
  end

  def asked_text(caso)
    hora = caso.metadata.dig('servicio', 'time')
    hora.present? ? " (pidió las #{hora})" : ''
  end

  RULES = <<~RULES
    Un cliente de una empresa de grúas recibió opciones de horario para sus servicios. Cada
    opción tiene un código («1A» = servicio 1, opción A). Lee su respuesta y di qué quiso.

    accion:
    - "elegir": acepta o escoge.
      · Afirmación general sin decir cuál («sí», «adelante», «ok», «va», «perfecto», «confirmo»,
        «adelante con el horario», «está bien», «sale», «me parece»): general = true, codigos = [].
      · Dice cuál: por letra («la B», si hay un solo servicio), por hora («la de las 14» =
        la opción que empieza a las 14:00), por unidad («la TP-73»), por servicio y hora
        («el 2 a las 16») o por código («1B y 2A»): codigos = esos códigos, general = false.
        Solo códigos que estén en la lista.
    - "ambigua": acepta pero no se sabe cuál, o pide algo que no se puede ubicar en las
      opciones sin preguntar («sí pero más tarde», «el otro», «la segunda» con varios servicios).
    - "rechazo": no le sirve ninguna («ninguna», «no me sirve», «no puedo a esas horas»).
    - "otra": no responde a las opciones: hace una pregunta, da datos del servicio, pide una
      hora o un día concretos que NO están en las opciones («mejor el jueves a las 10»), cancela,
      o pide otra unidad.

    Responde SOLO este JSON:
    {"accion": "elegir|ambigua|rechazo|otra", "general": false, "codigos": []}
  RULES
  private_constant :RULES
end
