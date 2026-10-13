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
#
# CANAL PROPIO: el seguimiento se ata al canal de prueba aunque el agente tenga el suyo
# (10 de los 19 de la cuenta 2 están en Telegram). Antes se ataba al del agente, la
# validación lo rechazaba y toda la pila salía «sin respuesta» tras 2 min por prueba
# (F0, 13/10/2026). Se prueba con el modelo del canal de prueba: el informe lo dice.
# Si aun así no se puede asignar, la prueba sale al momento con el motivo, y si falla
# toda la primera tanda, la pila se detiene.
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
    save!(status: 'running', total: escenarios.size, done: 0, results: [], **sandbox)
    juez = ContactTrackings::Assistant::TestBatteryJudge.new(@account, training: @template.complementary_prompt)
    resultados = []
    escenarios.each_slice(PARALLEL) do |tanda|
      resultados.concat(batch(tanda, juez))
      return not_assigned!(escenarios, resultados) if resultados.all? { |r| r[:sin_agente] }

      save!(status: 'running', total: escenarios.size, done: resultados.size, results: resultados)
    end
    save!(status: 'done', total: escenarios.size, done: resultados.size, results: resultados, finished_at: Time.current.iso8601)
  end

  # Dónde y con qué modelo contesta el agente en la prueba (puede no ser su canal real).
  def sandbox
    { sandbox: { 'inbox_id' => @inbox.id, 'inbox' => @inbox.name,
                 'model' => ContactTrackings::EngineConfig.model_for(@inbox, :conversational) } }
  end

  # La primera tanda entera sin agente: las demás saldrían igual.
  def not_assigned!(escenarios, resultados)
    save!(status: 'failed', error: 'not_assigned', detail: resultados.first[:motivo], total: escenarios.size,
          done: resultados.size, results: resultados, finished_at: Time.current.iso8601)
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
    asignacion = ContactTrackings::TemplateAssignment.new(conversacion, @template, inbox_id: @inbox.id)
    return not_assigned(escenario, conversacion, asignacion.error) unless asignacion.call

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
    Conversation.create!(account: @account, inbox: @inbox, contact: contacto,
                         contact_inbox: contacto_canal, status: :open)
  end

  # Sin seguimiento no contesta nadie: no se manda el mensaje ni se espera.
  def not_assigned(escenario, conversacion, error)
    # En español, como los motivos del juez (TestBatteryJudge).
    motivo = "No se pudo asignar el agente a la conversación de prueba: #{error}"
    escenario.to_h.merge(conversation: conversacion.display_id, reply: '', cases: [], cumple: false,
                         fallas: [motivo], motivo: motivo, sin_agente: true)
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
