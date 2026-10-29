# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — LA PILA DE PRUEBAS, EN VIVO (M5 de docs/importar_prompt_extenso_plan.md)
# ================================================================================
# «Probar sin enviar nada» (DryRunService) no redacta la respuesta, a propósito: una
# respuesta armada por otro camino diría otra cosa que el agente de verdad. Para saber
# CÓMO contesta hay que hacerlo contestar. Es lo que se hizo a mano con ADAM: una
# conversación por prueba, en un canal de pruebas, con el motor real.
#
# DÓNDE: solo en un canal API SIN webhook de la cuenta (TestBattery.sandbox_inbox): ahí
# un mensaje no sale a ninguna parte. Nunca en WhatsApp, Telegram ni un canal con webhook.
# NUNCA AGENDA: cada prueba es un solo mensaje; si el agente ofrece horarios, nadie elige.
# Los casos que abra el agente sí quedan (en ese canal): son parte de lo que se prueba.
#
# El avance y el resultado viven en la caché (TestBattery.key) dos días.
# ================================================================================

class ContactTrackings::Assistant::TestBatteryJob < ApplicationJob
  queue_as :low

  PARALLEL = 4
  WAIT_SECONDS = 120
  QUIET_SECONDS = 8

  def perform(battery_id, account_id, template_id, brief_id = nil, messages = nil, case_ids = nil) # rubocop:disable Metrics/ParameterLists
    @id = battery_id
    @account = Account.find(account_id)
    @template = TrackingTemplate.find(template_id)
    @inbox = ContactTrackings::Assistant::TestBattery.sandbox_inbox(@account)
    return save!(status: 'failed', error: 'no_sandbox') if @inbox.nil?

    run(scenarios(brief_id, messages, case_ids))
  rescue StandardError => e
    Rails.logger.error "[TestBattery] #{e.class}: #{e.message}"
    save!(status: 'failed', error: 'unavailable')
  end

  private

  def scenarios(brief_id, messages, case_ids)
    return ContactTrackings::Assistant::TestBatteryScenarios.from_cases(@template, case_ids) if case_ids.present?
    return ContactTrackings::Assistant::TestBatteryScenarios.own(messages) if messages.present?

    scenarios_for(brief_id)
  end

  def scenarios_for(brief_id)
    brief = brief_id && TrackingAgentBrief.find_by(id: brief_id, account: @account)
    ContactTrackings::Assistant::TestBatteryScenarios.new(@account, template: @template, brief: brief).call
  end

  def run(escenarios)
    save!(status: 'running', total: escenarios.size, done: 0, results: [])
    juez = ContactTrackings::Assistant::TestBatteryJudge.new(@account, training: @template.complementary_prompt)
    resultados = []
    escenarios.each_slice(PARALLEL) do |tanda|
      resultados.concat(batch(tanda, juez))
      save!(status: 'running', total: escenarios.size, done: resultados.size, results: resultados)
    end
    save!(status: 'done', total: escenarios.size, done: resultados.size, results: resultados, finished_at: Time.current.iso8601)
  end

  # Sin soltar el candado de carga mientras espera, en desarrollo un hilo que carga una clase
  # por primera vez se queda esperando para siempre (medido el 29/09/2026: la pila se detuvo en
  # la segunda tanda).
  def batch(tanda, juez)
    hilos = tanda.map { |e| Thread.new { Rails.application.executor.wrap { one(e, juez) } } }
    ActiveSupport::Dependencies.interlock.permit_concurrent_loads { hilos.map(&:value) }
  end

  # Una prueba: una conversación nueva, el mensaje (o los del diálogo, F5) del cliente, la
  # respuesta y su calificación. En un diálogo cada mensaje espera su respuesta, la traza
  # es la del último turno y el juez califica el diálogo entero.
  def one(escenario, juez)
    conversacion = new_conversation(escenario)
    return without_tracking(escenario, conversacion) unless ContactTracking.exists?(conversation_id: conversacion.id)

    dialogo, ultimo = converse(conversacion, Array(escenario.turns).presence || [escenario.message])
    respuesta = dialogo.last[:reply]
    traza = trace(conversacion, ultimo)
    fila = escenario.to_h.merge(conversation: conversacion.display_id, reply: respuesta, cases: cases(conversacion),
                                traza: traza, dialog: (dialogo if dialogo.size > 1),
                                **juez.call(graded(escenario, dialogo), respuesta, traza: traza))
    remember(escenario, fila)
    fila
  end

  # F3: una prueba de la pila guardada se queda con su resultado.
  def remember(escenario, fila)
    return unless escenario.id.to_s.start_with?('caso:')

    ContactTrackings::Assistant::TestCases.store_live(@account, escenario.id.delete_prefix('caso:'), fila)
  end

  # Sin seguimiento el agente no contesta: la prueba sale en rojo con el motivo en vez de
  # esperar WAIT_SECONDS una respuesta que no va a llegar.
  def without_tracking(escenario, conversacion)
    fila = escenario.to_h.merge(conversation: conversacion.display_id, reply: '', cases: [], traza: nil, cumple: false,
                                fallas: [], ruta_ok: nil, motivo: 'No se pudo asignar el agente a la conversación de prueba.')
    remember(escenario, fila)
    fila
  end

  # En un diálogo el juez ve como «cliente» todo lo anterior y califica la última respuesta.
  def graded(escenario, dialogo)
    return escenario if dialogo.size < 2

    escenario.dup.tap { |e| e.message = transcript(dialogo) }
  end

  # [[{ customer:, reply: }, …], id del último mensaje antes del último turno]
  def converse(conversacion, mensajes)
    ultimo = nil
    dialogo = mensajes.map do |texto|
      ultimo = conversacion.messages.maximum(:id).to_i
      conversacion.messages.create!(account: @account, inbox: @inbox, sender: conversacion.contact,
                                    message_type: :incoming, content: texto)
      { customer: texto, reply: wait_reply(conversacion, ultimo) }
    end
    [dialogo, ultimo]
  end

  # El diálogo para el juez, sin la última respuesta (es la que se califica).
  def transcript(dialogo)
    lineas = dialogo.each_with_index.flat_map do |turno, i|
      ["Cliente: #{turno[:customer]}", i < dialogo.size - 1 ? "Agente: #{turno[:reply]}" : nil]
    end
    lineas.compact.join("\n")
  end

  # proyecto@diagrama_agente_ia F2: por dónde pasó (F0). La de la primera respuesta del turno.
  def trace(conversacion, desde)
    conversacion.messages.where('id > ?', desde).where(message_type: :outgoing, private: false).order(:id)
                .filter_map { |m| m.content_attributes['traza'] }.first
  end

  def new_conversation(escenario)
    contacto = @account.contacts.create!(name: "Prueba #{@template.name.truncate(30)} · #{escenario.id.truncate(40)}")
    contacto_canal = ContactInbox.create!(contact: contacto, inbox: @inbox, source_id: SecureRandom.uuid)
    conversacion = Conversation.create!(account: @account, inbox: @inbox, contact: contacto,
                                        contact_inbox: contacto_canal, status: :open)
    # En el canal de pruebas, no en la bandeja del agente: ver ActionService#assign_tracking_template.
    ActionService.new(conversacion).assign_tracking_template([@template.id], inbox_id: @inbox.id)
    conversacion
  end

  # Espera hasta que el agente conteste y se quede callado QUIET_SECONDS, o WAIT_SECONDS.
  def wait_reply(conversacion, desde)
    inicio = Time.current
    loop do
      sleep 3
      salientes = conversacion.messages.where('id > ?', desde).where(message_type: :outgoing, private: false).order(:id)
      break if salientes.any? && Time.current - salientes.last.created_at > QUIET_SECONDS
      break if Time.current - inicio > WAIT_SECONDS
    end
    conversacion.messages.where('id > ?', desde).where(message_type: :outgoing, private: false).order(:id).pluck(:content).join("\n\n")
  end

  def cases(conversacion)
    CaseTicket.where(conversation_id: conversacion.id).map { |k| "#{k.folio} #{k.title.to_s.truncate(60)}" }
  end

  def save!(estado)
    anterior = Rails.cache.read(ContactTrackings::Assistant::TestBattery.key(@id)) || {}
    Rails.cache.write(ContactTrackings::Assistant::TestBattery.key(@id), anterior.merge(estado.stringify_keys),
                      expires_in: ContactTrackings::Assistant::TestBattery::TTL)
  end
end
