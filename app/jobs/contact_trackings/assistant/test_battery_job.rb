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

  def perform(battery_id, account_id, template_id, brief_id = nil)
    @id = battery_id
    @account = Account.find(account_id)
    @template = TrackingTemplate.find(template_id)
    @inbox = ContactTrackings::Assistant::TestBattery.sandbox_inbox(@account)
    return save!(status: 'failed', error: 'no_sandbox') if @inbox.nil?

    run(scenarios_for(brief_id))
  rescue StandardError => e
    Rails.logger.error "[TestBattery] #{e.class}: #{e.message}"
    save!(status: 'failed', error: 'unavailable')
  end

  private

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

  # Una prueba: una conversación nueva, un mensaje del cliente, la respuesta y su calificación.
  def one(escenario, juez)
    conversacion = new_conversation(escenario)
    ultimo = conversacion.messages.maximum(:id).to_i
    conversacion.messages.create!(account: @account, inbox: @inbox, sender: conversacion.contact,
                                  message_type: :incoming, content: escenario.message)
    respuesta = wait_reply(conversacion, ultimo)
    escenario.to_h.merge(conversation: conversacion.display_id, reply: respuesta, cases: cases(conversacion),
                         **juez.call(escenario, respuesta))
  end

  def new_conversation(escenario)
    contacto = @account.contacts.create!(name: "Prueba #{@template.name.truncate(30)} · #{escenario.id.truncate(40)}")
    contacto_canal = ContactInbox.create!(contact: contacto, inbox: @inbox, source_id: SecureRandom.uuid)
    conversacion = Conversation.create!(account: @account, inbox: @inbox, contact: contacto,
                                        contact_inbox: contacto_canal, status: :open)
    ActionService.new(conversacion).assign_tracking_template([@template.id])
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
