# frozen_string_literal: true

require 'rails_helper'

# Agentes listos — Atención a prospectos. OpenAI no se llama: se simulan sus respuestas
# (ReadyAgents::Runner#complete).
RSpec.describe ReadyAgents::Runner do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator, name: 'John') }
  let(:seller) { create(:user, account: account, role: :agent, name: 'Ana López') }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Mario Pérez') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, assignee: nil) }
  let(:objective) { 'handoff' }
  let!(:agent) do
    ReadyAgent.create!(account: account, kind: 'prospects', name: 'Sofi', enabled: true, inbox_ids: [inbox.id], created_by: admin,
                       settings: { 'objective' => objective, 'questions' => 'qué busca y su ciudad',
                                   'handoff_user_id' => seller.id })
  end

  def tool_call(name, args)
    { 'role' => 'assistant', 'content' => nil,
      'tool_calls' => [{ 'id' => "call_#{name}", 'type' => 'function', 'function' => { 'name' => name, 'arguments' => args.to_json } }] }
  end

  def answer(text) = { 'role' => 'assistant', 'content' => text }

  def stub_model(*replies)
    allow_any_instance_of(described_class).to receive(:complete).and_return(*replies) # rubocop:disable RSpec/AnyInstance
  end

  def incoming(text)
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming, content: text)
  end

  def reply_to(message) = ReadyAgents::ReplyJob.perform_now(message.id)

  def session = ReadyAgentSession.find_by(conversation_id: conversation.id)

  before do
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' })
  end

  it 'el mensaje del cliente en su bandeja lo contesta el agente listo' do
    expect { incoming('Hola, info') }.to have_enqueued_job(ReadyAgents::ReplyJob)
  end

  it 'contesta, guarda lo que el prospecto dijo y el mensaje sale a nombre del agente' do
    stub_model(tool_call('guardar_respuesta', { pregunta: 'Qué busca', respuesta: 'Paneles solares' }),
               answer('¡Hola Mario! ¿En qué ciudad estás?'))
    reply_to(incoming('Busco paneles solares'))

    sent = conversation.messages.outgoing.where(private: false).last
    expect(sent.content).to eq('¡Hola Mario! ¿En qué ciudad estás?')
    expect(sent.content_attributes).to include('ai_agent' => true, 'ai_agent_name' => 'Sofi')
    expect(session).to have_attributes(status: 'active', answers: { 'Qué busca' => 'Paneles solares' })
  end

  it 'calificado: etiqueta «interesado», nota con sus respuestas y se pasa a la persona' do
    stub_model(tool_call('prospecto_calificado', { resumen: 'Quiere paneles para su casa en Monterrey' }),
               answer('¡Listo! Ana te escribe en un momento.'))
    reply_to(incoming('Sí, quiero cotizar ya'))

    expect(conversation.reload.label_list).to include('interesado')
    expect(conversation.assignee_id).to eq(seller.id)
    expect(conversation.messages.where(private: true).last.content).to include('Prospecto calificado', 'Monterrey')
    expect(session.status).to eq('qualified')
  end

  it 'con temperatura: etiqueta «prospecto-caliente» y la temperatura en la nota (reemplaza a la anterior)' do
    conversation.update_labels(['prospecto-frio'])
    stub_model(tool_call('prospecto_calificado', { resumen: 'Lo quiere este mes', temperatura: 'caliente' }),
               answer('¡Listo! Ana te escribe.'))
    reply_to(incoming('Lo necesito ya y tengo el presupuesto'))

    expect(conversation.reload.label_list).to include('interesado', 'prospecto-caliente')
    expect(conversation.label_list).not_to include('prospecto-frio')
    expect(conversation.messages.where(private: true).last.content).to include('Temperatura: 🔥 caliente')
  end

  it 'con datos obligatorios: no lo califica hasta tener su correo' do
    agent.update!(settings: agent.settings.merge('required_contact' => %w[email]))
    stub_model(tool_call('prospecto_calificado', { resumen: 'Listo', temperatura: 'tibio' }),
               answer('¿Me compartes tu correo para enviarte la propuesta?'))
    reply_to(incoming('Sí, me interesa'))

    expect(session.status).to eq('active')
    expect(conversation.reload.label_list).not_to include('interesado')
  end

  it 'con datos obligatorios: si los da en el mismo turno, sí lo califica y los guarda' do
    agent.update!(settings: agent.settings.merge('required_contact' => %w[email company]))
    stub_model(tool_call('actualizar_contacto', { correo: 'Mario@Acme.com', empresa: 'Acme' }),
               tool_call('prospecto_calificado', { resumen: 'Listo', temperatura: 'tibio' }), answer('¡Gracias! Ana te escribe.'))
    reply_to(incoming('mario@acme.com, de Acme'))

    expect(session.status).to eq('qualified')
    expect(contact.reload).to have_attributes(email: 'mario@acme.com')
    expect(contact.additional_attributes).to include('company_name' => 'Acme')
  end

  it 'el Catálogo de productos solo si la empresa lo marcó; si no, solo respuestas predefinidas' do
    names = ->(runner) { runner.send(:tools).map { |t| t.dig(:function, :name) } }
    expect(names.call(described_class.new(agent))).not_to include('buscar_en_catalogo')
    expect(names.call(described_class.new(agent))).to include('buscar_respuesta_predefinida')
    expect(described_class.new(agent).send(:tool, 'buscar_en_catalogo', { 'consulta' => 'precio' })).to include(:error)

    agent.update!(settings: agent.settings.merge('business_use_catalog' => true))
    expect(names.call(described_class.new(agent))).to include('buscar_en_catalogo')
  end

  context 'with objetivo «crear la oportunidad»' do
    let(:objective) { 'opportunity' }

    it 'crea el caso comercial para la persona' do
      CaseType.create!(account: account, name: 'Oportunidad', color: '#22c55e', case_class: :commercial)
      stub_model(tool_call('prospecto_calificado', { resumen: 'Paneles para casa' }), answer('¡Gracias! Te escribimos.'))
      reply_to(incoming('Me interesa'))

      ticket = CaseTicket.find_by(contact_id: contact.id)
      expect(ticket).to have_attributes(assignee_id: seller.id, conversation_id: conversation.id)
      expect(ticket.case_type.case_class).to eq('commercial')
      expect(session.outcome).to include(ticket.folio)
    end
  end

  context 'with objetivo «agendarle una cita»' do
    let(:objective) { 'appointment' }

    it 'ofrece horarios, agenda la cita y queda atendiendo por si la quiere mover' do
      integration = UserCalendarIntegration.create!(account: account, user: seller, google_email: 'ana@x.com', tokens: {})
      agent.update!(settings: agent.settings.merge('appointment_user_ids' => [seller.id.to_s]))
      start = 2.days.from_now.change(hour: 11, min: 0, sec: 0)
      slot = { slot: start, end_time: start + 30.minutes, agent_name: 'Ana López', calendar_integration_id: integration.id }
      allow_any_instance_of(ContactTrackings::AvailabilitySlotService).to receive(:slot_for).and_return(slot) # rubocop:disable RSpec/AnyInstance
      allow(Cases::MeetingSyncJob).to receive(:perform_later)
      stub_model(tool_call('agendar_cita', { inicio: start.strftime('%Y-%m-%dT%H:%M') }), answer('¡Listo! Te esperamos.'))

      reply_to(incoming('El jueves a las 11 me queda'))

      expect(session.case_meeting).to have_attributes(organizer_id: seller.id, starts_at: start)
      expect(session).to have_attributes(status: 'active', outcome: include('Cita'))
      expect(conversation.reload.assignee_id).to eq(seller.id)
    end

    it 'sin acceso al calendario: lo pasa a una persona con nota de a quién reconectar' do
      UserCalendarIntegration.create!(account: account, user: seller, google_email: 'ana@x.com', tokens: {})
      agent.update!(settings: agent.settings.merge('appointment_user_ids' => [seller.id.to_s]))
      allow_any_instance_of(ContactTrackings::AvailabilitySlotService).to receive_messages( # rubocop:disable RSpec/AnyInstance
        call: [], calendars_unreadable?: true, unreadable_users: ['Ana López']
      )
      stub_model(tool_call('ver_horarios', {}), tool_call('prospecto_calificado', { resumen: 'Quiere cita' }),
                 answer('En un momento alguien del equipo te confirma el horario.'))

      reply_to(incoming('¿Qué horarios tienes?'))

      expect(session.status).to eq('handed_off')
      note = conversation.messages.where(private: true).last.content
      expect(note).to include('Pasa a una persona', 'Ana López', 'reconéctalo')
    end
  end

  it 'descartar: nota con el motivo y la conversación se resuelve' do
    stub_model(tool_call('descartar', { motivo: 'Busca empleo, no producto' }), answer('Gracias por escribir, ¡suerte!'))
    reply_to(incoming('¿Tienen vacantes?'))

    expect(conversation.reload).to be_resolved
    expect(session).to have_attributes(status: 'discarded', outcome: 'Busca empleo, no producto')
  end

  it 'a quien ya es cliente lo pasa a su responsable fijo sin preguntarle nada' do
    owner = create(:user, account: account, role: :agent, name: 'Luis Gómez')
    organization = Organization.create!(account: account, name: 'Acme', stage: :customer)
    contact.update!(organization: organization, owner_id: owner.id)
    allow_any_instance_of(described_class).to receive(:complete).and_raise('no debe llamar al modelo') # rubocop:disable RSpec/AnyInstance

    reply_to(incoming('Hola, ¿cómo va mi pedido?'))

    expect(conversation.reload.assignee_id).to eq(owner.id)
    expect(conversation.messages.where(private: false).outgoing.last.content).to eq('¡Hola Mario! Te comunico con Luis, en un momento te escribe.')
    expect(session.status).to eq('client')
  end

  it 'si una persona ya le escribió, el agente no entra; si entra después, se pausa' do
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, sender: seller, content: 'Hola, soy Ana')
    expect(ReadyAgents::Router.takes?(incoming('Hola'))).to be(false)

    other = create(:conversation, account: account, inbox: inbox, contact: create(:contact, account: account))
    ReadyAgentSession.create!(account: account, ready_agent: agent, conversation: other, created_at: 1.hour.ago)
    create(:message, account: account, inbox: inbox, conversation: other, message_type: :outgoing, sender: seller, content: 'Yo lo atiendo')
    message = create(:message, account: account, inbox: inbox, conversation: other, message_type: :incoming, content: 'ok')
    stub_model(answer('no debe salir'))
    ReadyAgents::ReplyJob.perform_now(message.id)
    expect(ReadyAgentSession.find_by(conversation_id: other.id).status).to eq('paused')
  end

  it 'una bandeja solo puede tener un agente listo prendido' do
    other = ReadyAgent.new(account: account, kind: 'prospects', name: 'Otro', enabled: true, inbox_ids: [inbox.id])
    expect(other).not_to be_valid
    expect(other.errors[:inbox_ids].join).to include('Sofi')
  end

  it 'chat de prueba: contesta sin guardar ni mandar nada' do
    stub_model(tool_call('guardar_respuesta', { pregunta: 'Ciudad', respuesta: 'Monterrey' }), answer('¡Perfecto! ¿Para cuándo lo necesitas?'))
    result = described_class.new(agent, history: [{ role: 'user', content: 'Soy de Monterrey' }]).test

    expect(result).to include(reply: '¡Perfecto! ¿Para cuándo lo necesitas?', answers: { 'Ciudad' => 'Monterrey' })
    expect(result[:tools].pluck(:name)).to eq(['guardar_respuesta'])
    expect(ReadyAgentSession.count).to eq(0)
  end
end
