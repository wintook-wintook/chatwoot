# frozen_string_literal: true

require 'rails_helper'

# Función «Atención a prospectos» sobre el motor 2.0 (Plan-Motor-Agentes §11.14.5): las mismas
# pruebas que tenía el agente listo de antes (spec/services/ready_agents/runner_spec.rb), ahora con
# el agente en la lista de agentes. OpenAI no se llama: se simulan sus respuestas (Motor2::Runner#complete).
RSpec.describe Motor2::Functions::Prospects do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator, name: 'John') }
  let(:seller) { create(:user, account: account, role: :agent, name: 'Ana López') }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Mario Pérez') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, assignee: nil) }
  let(:objective) { 'handoff' }
  let(:settings) { { 'objective' => objective, 'questions' => 'qué busca y su ciudad', 'handoff_user_id' => seller.id } }
  let!(:agent) { save_agent(settings) }

  def save_agent(answers, template: nil)
    Motor2::Functions::Form.new(account, { kind: 'prospects', name: 'Prospectos Facebook', display_name: 'Sofi', enabled: true,
                                           inbox_ids: [inbox.id], settings: answers }, user: admin, template: template).save
  end

  def tool_call(name, args)
    { 'role' => 'assistant', 'content' => nil,
      'tool_calls' => [{ 'id' => "call_#{name}", 'type' => 'function', 'function' => { 'name' => name, 'arguments' => args.to_json } }] }
  end

  def answer(text) = { 'role' => 'assistant', 'content' => text }

  def stub_model(*replies)
    allow_any_instance_of(Motor2::Runner).to receive(:complete).and_return(*replies) # rubocop:disable RSpec/AnyInstance
  end

  def incoming(text, conv = conversation)
    create(:message, account: account, inbox: inbox, conversation: conv, message_type: :incoming, content: text, sender: conv.contact)
  end

  def reply_to(message) = Motor2::ReplyJob.perform_now(message.id)

  def tracking = ContactTracking.find_by(conversation_id: conversation.id)

  def note = conversation.messages.where(private: true).order(:id).last.content

  before do
    admin
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' })
  end

  it 'queda en la lista de agentes como agente 2.0 de «Atención a prospectos»' do
    expect(agent).to have_attributes(engine: '2', agent_function: 'prospects', attending: true, attend_inbox_ids: [inbox.id],
                                     inbox_id: inbox.id, customer_display_name: 'Sofi', function_title: 'Atención a prospectos')
    expect(agent.motor2['answers']).to include('objective' => 'handoff', 'handoff_user_id' => seller.id)
    expect(Motor2Version.where(tracking_template_id: agent.id).count).to eq(1)
  end

  it 'el prompt trae el puesto, el negocio, las preguntas prendidas, las objeciones y los datos a juntar' do
    save_agent(settings.merge('business_what' => 'Paneles solares', 'qualify' => [{ 'key' => 'budget', 'on' => true, 'text' => '' }],
                              'objections' => [{ 'objection' => 'Está caro', 'answer' => 'Se paga solo en 4 años' }],
                              'required_contact' => %w[email]), template: agent)
    runner = Motor2::Runner.new(Motor2::Config.new(agent.reload), state: Motor2::State.new, history: [])
    system = Motor2::Prompt.new(runner, Motor2::Skills.for(runner)).system

    expect(system).to include('ERES: el primer contacto', 'Qué vende: Paneles solares', 'Presupuesto', 'Qué necesita y para qué',
                              '«Está caro» → Se paga solo', 'DATOS OBLIGATORIOS', 'su correo', 'TEMPERATURA')
  end

  it 'el mensaje del cliente en su bandeja lo toma el motor 2.0 (sin automatización)' do
    expect { incoming('Hola, info') }.to have_enqueued_job(Motor2::ReplyJob)
    expect(ContactTrackingResponseAnalyzerJob).not_to have_been_enqueued
  end

  it 'contesta, guarda lo que el prospecto dijo y el seguimiento queda activo y sin intentos' do
    stub_model(tool_call('guardar_respuesta', { pregunta: 'Qué busca', respuesta: 'Paneles solares' }),
               answer('¡Hola Mario! ¿En qué ciudad estás?'))
    reply_to(incoming('Busco paneles solares'))

    sent = conversation.messages.outgoing.where(private: false).last
    expect(sent.content).to eq('¡Hola Mario! ¿En qué ciudad estás?')
    expect(sent.content_attributes).to include('ai_agent' => true)
    expect(tracking).to have_attributes(status: 'active', tracking_template_id: agent.id, max_attempts: 1)
    expect(tracking.scheduled_for).to be > 1.year.from_now
    expect(tracking.motor2_state['answers']).to eq('Qué busca' => 'Paneles solares')
  end

  it 'calificado: etiqueta «interesado», nota con sus respuestas y se pasa a la persona' do
    stub_model(tool_call('prospecto_calificado', { resumen: 'Quiere paneles para su casa en Monterrey', temperatura: 'tibio' }),
               answer('¡Listo! Ana te escribe en un momento.'))
    reply_to(incoming('Sí, quiero cotizar ya'))

    expect(conversation.reload.label_list).to include('interesado', 'prospecto-tibio')
    expect(conversation.assignee_id).to eq(seller.id)
    expect(note).to include('Prospecto calificado', 'Monterrey', 'Temperatura: 🌤 tibio')
    expect(tracking).to have_attributes(status: 'objective_met', outcome: start_with('qualified'))
  end

  it 'con temperatura, la nueva etiqueta reemplaza a la anterior' do
    conversation.update_labels(['prospecto-frio'])
    stub_model(tool_call('prospecto_calificado', { resumen: 'Lo quiere este mes', temperatura: 'caliente' }), answer('¡Listo!'))
    reply_to(incoming('Lo necesito ya y tengo el presupuesto'))

    expect(conversation.reload.label_list).to include('interesado', 'prospecto-caliente')
    expect(conversation.label_list).not_to include('prospecto-frio')
  end

  it 'con datos obligatorios: no lo califica hasta tener su correo' do
    save_agent(settings.merge('required_contact' => %w[email]), template: agent)
    stub_model(tool_call('prospecto_calificado', { resumen: 'Listo', temperatura: 'tibio' }),
               answer('¿Me compartes tu correo para enviarte la propuesta?'))
    reply_to(incoming('Sí, me interesa'))

    expect(tracking.status).to eq('active')
    expect(conversation.reload.label_list).not_to include('interesado')
  end

  it 'con datos obligatorios: si los da en el mismo turno, sí lo califica y los guarda' do
    save_agent(settings.merge('required_contact' => %w[email company]), template: agent)
    stub_model(tool_call('actualizar_contacto', { correo: 'mario@acme.com', empresa: 'Acme' }),
               tool_call('prospecto_calificado', { resumen: 'Listo', temperatura: 'tibio' }), answer('¡Gracias! Ana te escribe.'))
    reply_to(incoming('mario@acme.com, de Acme'))

    expect(tracking.status).to eq('objective_met')
    expect(contact.reload).to have_attributes(email: 'mario@acme.com')
    expect(contact.additional_attributes).to include('company_name' => 'Acme')
  end

  it 'el Catálogo de productos solo si la empresa lo marcó' do
    names = lambda do
      runner = Motor2::Runner.new(Motor2::Config.new(agent.reload), state: Motor2::State.new, history: [])
      Motor2::Skills.for(runner).flat_map(&:tools).map { |t| t.dig(:function, :name) }
    end
    expect(names.call).to include('guardar_respuesta', 'prospecto_calificado', 'descartar', 'pasar_a_humano')
    expect(names.call).not_to include('buscar_en_catalogo', 'objetivo_cumplido', 'ver_horarios')

    save_agent(settings.merge('business_use_catalog' => true), template: agent)
    expect(names.call).to include('buscar_en_catalogo')
  end

  context 'with objetivo «crear la oportunidad»' do
    let(:objective) { 'opportunity' }

    it 'crea el caso comercial para la persona' do
      CaseType.create!(account: account, name: 'Oportunidad', color: '#22c55e', case_class: :commercial)
      stub_model(tool_call('prospecto_calificado', { resumen: 'Paneles para casa', temperatura: 'caliente' }), answer('¡Gracias!'))
      reply_to(incoming('Me interesa'))

      ticket = CaseTicket.find_by(contact_id: contact.id)
      expect(ticket).to have_attributes(assignee_id: seller.id, conversation_id: conversation.id)
      expect(tracking.outcome).to include(ticket.folio)
    end
  end

  context 'with objetivo «agendarle una cita»' do
    let(:objective) { 'appointment' }
    let!(:integration) { UserCalendarIntegration.create!(account: account, user: seller, google_email: 'ana@x.com', tokens: {}) }

    before { save_agent(settings.merge('appointment_user_ids' => [seller.id.to_s], 'appointment_minutes' => '45'), template: agent) }

    it 'agenda la cita con quien se eligió, etiqueta, nota y se la asigna; sigue atendiendo' do
      start = 2.days.from_now.change(hour: 11, min: 0, sec: 0)
      slot = { slot: start, end_time: start + 45.minutes, agent_name: 'Ana López', calendar_integration_id: integration.id }
      allow_any_instance_of(ContactTrackings::AvailabilitySlotService).to receive(:slot_for).and_return(slot) # rubocop:disable RSpec/AnyInstance
      allow(Cases::MeetingSyncJob).to receive(:perform_later)
      stub_model(tool_call('agendar_cita', { inicio: start.strftime('%Y-%m-%dT%H:%M') }), answer('¡Listo! Te esperamos.'))

      reply_to(incoming('El jueves a las 11 me queda'))

      meeting = CaseMeeting.find(tracking.motor2_state.dig('appointment', 'meeting_id'))
      expect(meeting).to have_attributes(organizer_id: seller.id, starts_at: start)
      expect(tracking).to have_attributes(status: 'active', outcome: include('Cita'))
      expect(conversation.reload.assignee_id).to eq(seller.id)
      expect(conversation.label_list).to include('interesado')
      expect(note).to include('Cita agendada')
    end

    it 'sin acceso al calendario: lo pasa a una persona con nota de a quién reconectar' do
      allow_any_instance_of(ContactTrackings::AvailabilitySlotService).to receive_messages( # rubocop:disable RSpec/AnyInstance
        call: [], calendars_unreadable?: true, unreadable_users: ['Ana López']
      )
      stub_model(tool_call('ver_horarios', {}), answer('En un momento alguien del equipo te confirma el horario.'))
      reply_to(incoming('¿Qué horarios tienes?'))

      expect(tracking).to have_attributes(status: 'paused', outcome: 'handed_off')
      expect(note).to include('Pasa a una persona', 'Ana López', 'reconéctalo')
    end
  end

  it 'descartar: nota con el motivo y la conversación se resuelve' do
    stub_model(tool_call('descartar', { motivo: 'Busca empleo, no producto' }), answer('Gracias por escribir, ¡suerte!'))
    reply_to(incoming('¿Tienen vacantes?'))

    expect(conversation.reload).to be_resolved
    expect(tracking).to have_attributes(status: 'cancelled', outcome: 'discarded')
    expect(note).to include('Descartado: Busca empleo')
  end

  it 'a quien ya es cliente lo pasa a su responsable fijo sin preguntarle nada' do
    owner = create(:user, account: account, role: :agent, name: 'Luis Gómez')
    organization = Organization.create!(account: account, name: 'Acme', stage: :customer)
    contact.update!(organization: organization, owner_id: owner.id)
    allow_any_instance_of(Motor2::Runner).to receive(:complete).and_raise('no debe llamar al modelo') # rubocop:disable RSpec/AnyInstance

    reply_to(incoming('Hola, ¿cómo va mi pedido?'))

    expect(conversation.reload.assignee_id).to eq(owner.id)
    expect(conversation.messages.where(private: false).outgoing.last.content).to eq('¡Hola Mario! Te comunico con Luis, en un momento te escribe.')
    expect(tracking).to have_attributes(status: 'objective_met', outcome: 'client')
    stub_model(answer('no debe salir'))
    expect(Motor2.takes?(incoming('¿sigues ahí?'))).to be(false)
  end

  it 'si una persona ya le escribió, el agente no entra; si entra después, se pausa' do
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, sender: seller, content: 'Hola, soy Ana')
    expect(Motor2.takes?(incoming('Hola'))).to be(false)

    other = create(:conversation, account: account, inbox: inbox, contact: create(:contact, account: account))
    stub_model(answer('Hola, ¿qué buscas?'))
    reply_to(incoming('Hola', other))
    create(:message, account: account, inbox: inbox, conversation: other, message_type: :outgoing, sender: seller, content: 'Yo lo atiendo')
    stub_model(answer('no debe salir'))
    reply_to(incoming('ok', other))
    expect(ContactTracking.find_by(conversation_id: other.id).status).to eq('paused')
  end

  it 'si la conversación ya tiene otro agente (campaña o automatización), manda ese' do
    other = create(:tracking_template, account: account, inbox_id: inbox.id, objective: 'Vender la promo de becas')
    create(:contact_tracking, account: account, contact: contact, inbox: inbox, conversation: conversation, tracking_template: other)
    expect(Motor2::InboxRouter.agent_for(incoming('Hola'))).to be_nil
  end

  it 'una bandeja solo puede tener un agente que la atienda' do
    other = Motor2::Functions::Form.new(account, { kind: 'prospects', name: 'Otro', enabled: true, inbox_ids: [inbox.id], settings: {} },
                                        user: admin).build
    expect(other).not_to be_valid
    expect(other.errors[:attend_inbox_ids].join).to include('Prospectos Facebook')
  end

  it 'apagado no atiende la bandeja (pero sigue en la lista)' do
    agent.update!(attending: false)
    expect(Motor2.takes?(incoming('Hola'))).to be(false)
  end

  it 'lo que corrige el entrenador cae en «Indicaciones» (lo único de texto libre que enseña el asistente)' do
    cause = { 'kind' => 'agent', 'field' => 'never', 'replace' => 'Nunca prometas descuentos.', 'summary' => 'Sin descuentos' }
    Motor2::Trainer::AgentFix.new(agent, admin, cause).call

    expect(agent.reload.motor2['instructions']).to include('Nunca prometas descuentos.')
    expect(agent.motor2['never'].to_s).to be_empty
    expect(agent.motor2['answers']).to include('objective' => 'handoff')
  end

  it 'chat de prueba: contesta con el motor 2.0 sin guardar ni mandar nada' do
    stub_model(tool_call('guardar_respuesta', { pregunta: 'Ciudad', respuesta: 'Monterrey' }), answer('¡Perfecto! ¿Para cuándo?'))
    result = nil
    expect { result = Motor2::Probe.new(agent, messages: [{ role: 'user', content: 'Soy de Monterrey' }]).call }
      .not_to change(ContactTracking, :count)

    expect(result).to include(reply: '¡Perfecto! ¿Para cuándo?')
    expect(result[:state]['answers']).to eq('Ciudad' => 'Monterrey')
  end
end
