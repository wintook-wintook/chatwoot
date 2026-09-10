# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — ENTREVISTA Y REDACCIÓN
# ================================================================================
# UNA sola conversación con el modelo: entrevista y, cuando tiene lo que necesita,
# escribe el Entrenamiento. Si lo que escribió no pasa el comprobador, vuelve al
# MISMO hilo con el diagnóstico y lo corrige.
#
# POR QUÉ UNA CONVERSACIÓN Y NO AGENTES ENCADENADOS:
#   Un entrevistador que le pasa el objetivo a un generador, y ese a un auditor, es
#   más caro y peor: cada salto re-serializa el contexto y pierde el matiz de la
#   entrevista ("no sabía bien qué quería, terminamos en soporte + cobranza"). Y el
#   auditor-LLM es la pieza a ELIMINAR, no a encadenar: un modelo auditando sintaxis
#   opina; el parser verifica. Acá el auditor es ValidatorService, que no gasta
#   tokens y no puede alucinar.
#
# EL BUCLE:
#   redacta → comprueba → ¿bloqueantes? → vuelve al mismo hilo con el DIAGNÓSTICO
#   Tope duro de MAX_REPAIRS: sin tope, un contrato mal escrito quema tokens en
#   círculo. Al agotarse se devuelve el borrador con sus errores para que los vea
#   una persona, en vez de guardar algo roto.
#
#   El mensaje que se le devuelve es el del comprobador, textual. Medido el
#   08/09/2026: con un veredicto pelado se reparaba 1 de 3 veces; nombrando el
#   carácter que faltaba y su línea, 3 de 3.
#
# CONTRATO DE SALIDA:
#   Se pide JSON para que el bucle sea determinista: hace falta saber si el modelo
#   preguntó o entregó, y con texto libre eso habría que adivinarlo.
#     { "mensaje": "lo que se le muestra a la persona",
#       "entrenamiento": "el Entrenamiento completo, o null si todavía pregunta" }
# ================================================================================

class ContactTrackings::Assistant::InterviewService
  API_URL = 'https://api.openai.com/v1/chat/completions'
  READ_TIMEOUT = 90
  # Vueltas de corrección antes de mostrarle los errores a la persona.
  MAX_REPAIRS = 3
  # Los dos comportamientos posibles del agente. "responde" consulta una fuente y
  # escala si no resuelve; "deriva" abre el caso siempre, sin intentar contestar.
  # Cuál de los dos es NO se puede deducir del pedido —"un agente que junte
  # información para abrir un ticket" se lee de las dos maneras— así que el modelo
  # tiene que haberlo preguntado, y decirlo. Medido: si no se le exige, elige solo.
  MODES = %w[responde deriva].freeze
  # Tope de turnos de entrevista. Más que esto no es una entrevista, es un chat: a
  # partir de acá el contrato le exige redactar con lo que tenga y marcar lo que
  # falte como <PENDIENTE:>.
  MAX_INTERVIEW_TURNS = 5

  Result = Struct.new(:reply, :draft, :validation, :repairs, :proposal, :error, keyword_init: true) do
    def success? = error.blank?
  end

  # Los datos del agente que el asistente propone junto al Entrenamiento. Se
  # rescatan del JSON con cuidado: `contexto` es el único que puede hacer daño si
  # el modelo lo rellena de memoria —entra al prompt como "BASE DE CONOCIMIENTO" y
  # el agente lo cita como si fuera cierto—, así que se toma tal cual vino y la
  # pantalla lo muestra editable, nunca oculto.
  def self.proposal_from(reply)
    raw = reply['propuesta']
    return nil unless raw.is_a?(Hash)

    { name: raw['nombre'].to_s.strip, objective: raw['objetivo'].to_s.strip,
      ai_context: raw['contexto'].to_s.strip }
  end

  # one_shot: sin entrevista. Es el modo del botón "generar" que vive dentro de la
  # ficha del Agente IA: ahí no hay una conversación donde preguntar, hay un campo y
  # alguien esperando que se llene. Se redacta con lo que haya y lo que falte se marca
  # <PENDIENTE:>, en vez de devolver una pregunta que nadie va a poder contestar.
  def initialize(account, messages:, inbox: nil, one_shot: false)
    @account = account
    @inbox = inbox
    @messages = Array(messages)
    @one_shot = one_shot
  end

  def call
    return Result.new(error: :no_api_key) if api_key.blank?

    reply = ask(conversation)
    return Result.new(error: :unavailable) if reply.nil?

    draft = reply['entrenamiento'].presence
    return Result.new(reply: reply['mensaje'], draft: nil, repairs: 0) if draft.blank?
    # Entregar sin haber preguntado no es un error de sintaxis, así que el
    # comprobador no lo caza: es el modelo decidiendo por la persona. Se rechaza
    # acá y se lo devuelve al mismo hilo, igual que un hallazgo del comprobador.
    return ask_missing_mode(reply, draft) if MODES.exclude?(reply['modo'])

    repair(reply['mensaje'], draft, self.class.proposal_from(reply))
  end

  private

  attr_reader :account, :inbox, :messages, :one_shot

  # El modelo redactó sin preguntar. Se descarta el borrador y se le devuelve al
  # mismo hilo la pregunta que le faltó: es más barato que entregar un agente que
  # se comporta distinto de lo que la persona pidió, sin que nadie lo note.
  def ask_missing_mode(reply, draft)
    history = conversation + [
      { role: 'assistant', content: { mensaje: reply['mensaje'], entrenamiento: draft }.to_json },
      { role: 'user', content: t('repair.missing_mode') }
    ]

    corrected = ask(history)
    return Result.new(reply: reply['mensaje'], draft: nil, repairs: 0) if corrected.nil?

    nuevo = corrected['entrenamiento'].presence
    return Result.new(reply: corrected['mensaje'], draft: nil, repairs: 0) if nuevo.blank?

    repair(corrected['mensaje'], nuevo, self.class.proposal_from(corrected))
  end

  # ── el bucle ────────────────────────────────────────────────────────────────
  def repair(message, draft, proposal = nil)
    history = conversation
    repairs = 0
    validation = validate(draft)

    while validation[:blocking].any? && repairs < MAX_REPAIRS
      repairs += 1
      history += [{ role: 'assistant', content: { mensaje: message, entrenamiento: draft }.to_json },
                  { role: 'user', content: repair_prompt(validation[:blocking]) }]

      reply = ask(history)
      break if reply.nil? || reply['entrenamiento'].blank?

      message = reply['mensaje']
      draft = reply['entrenamiento']
      validation = validate(draft)
    end

    Result.new(reply: message, draft: draft, validation: validation,
               repairs: repairs, proposal: proposal)
  end

  # Se le devuelven los mensajes del comprobador TEXTUALES. Reescribirlos "para que
  # se entiendan mejor" es justo lo que los vuelve inútiles.
  def repair_prompt(blocking)
    detalle = blocking.map do |finding|
      linea = finding[:wrote].present? ? "\n  #{t('repair.wrote')} #{finding[:wrote]}" : ''
      "- #{finding[:message]}#{linea}"
    end

    "#{t('repair.header')}\n#{detalle.join("\n")}\n\n#{t('repair.footer')}"
  end

  # Los hallazgos ya vienen traducidos; el texto que los envuelve tiene que ir en el
  # mismo idioma o el modelo recibe un prompt mezclado.
  def t(key, **args)
    I18n.t("tracking_assistant.#{key}", locale: ContactTrackings::Assistant::Language.resolve, **args)
  end

  def validate(draft)
    ContactTrackings::Assistant::ValidatorService.new(draft, account: account).call
  end

  # ── el prompt ───────────────────────────────────────────────────────────────
  def conversation
    [{ role: 'system', content: system_prompt }] + messages.map { |m| m.slice('role', 'content').symbolize_keys }
  end

  # Las dos mitades: el contrato fijo y el inventario de ESTA cuenta.
  def system_prompt
    [
      ContactTrackings::Assistant::Contract.call,
      inventory_section,
      ContactTrackings::Assistant::Instructions.call(one_shot: one_shot,
                                                     max_turns: MAX_INTERVIEW_TURNS)
    ].join("\n\n")
  end

  def inventory_section
    inventory = ContactTrackings::Assistant::InventoryService.new(account, inbox: inbox).call
    ContactTrackings::Assistant::InventoryPrompt.call(inventory)
  end

  # ── OpenAI ──────────────────────────────────────────────────────────────────
  def ask(history)
    body = {
      model: ContactTrackings::EngineConfig.model_for(inbox, :authoring_assistant),
      messages: history,
      temperature: 0.2,
      max_tokens: ContactTrackings::EngineConfig.max_tokens_for(:authoring_assistant),
      response_format: { type: 'json_object' }
    }

    parse(post(body))
  end

  def post(body)
    response = http_client.request(build_request(body))
    return log_failure("HTTP #{response.code}: #{response.body.to_s[0, 300]}") unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).dig('choices', 0, 'message', 'content')
  rescue StandardError => e
    log_failure(e.message)
  end

  def http_client
    require 'net/http'
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = READ_TIMEOUT
    http
  end

  def build_request(body)
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'
    request.body = body.to_json
    request
  end

  def uri
    @uri ||= URI(API_URL)
  end

  def parse(content)
    return nil if content.blank?

    JSON.parse(content)
  rescue JSON::ParserError => e
    log_failure("respuesta no es JSON: #{e.message}")
  end

  def log_failure(detail)
    Rails.logger.error("[Asistente] #{detail}")
    nil
  end

  # Cada cuenta usa su propia integración OpenAI, igual que el resto del motor.
  def api_key
    @api_key ||= account.hooks.find_by(app_id: 'openai', status: 'enabled')&.settings&.dig('api_key').presence
  end
end
