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
  let(:settings) do
    { 'objective' => objective, 'question_list' => ['¿Qué buscas?', '¿En qué ciudad estás?'], 'handoff_user_id' => seller.id }
  end
  let!(:agent) { save_agent(settings) }

  # La frase para retomar cuando faltan varias preguntas (sin «me faltan 4 preguntas»).
  def neutral = '(Si te parece, seguimos\\.|Para ayudarte mejor:|Y para darte la mejor opción:)'

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
    # «¿Contesta la pregunta?» (Motor2::AnswerCheck): sí, salvo en las pruebas que lo cambian.
    allow_any_instance_of(Motor2::AnswerCheck).to receive_messages(answers?: true, about_business?: true) # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(Motor2::AnswerExtractor).to receive(:call).and_return({}) # rubocop:disable RSpec/AnyInstance
  end

  it 'queda en la lista de agentes como agente 2.0 de «Atención a prospectos»' do
    expect(agent).to have_attributes(engine: '2', agent_function: 'prospects', attending: true, attend_inbox_ids: [inbox.id],
                                     inbox_id: inbox.id, customer_display_name: 'Sofi', function_title: 'Atención a prospectos')
    expect(agent.motor2['answers']).to include('objective' => 'handoff', 'handoff_user_id' => seller.id)
    expect(Motor2Version.where(tracking_template_id: agent.id).count).to eq(1)
  end

  def system_prompt(state = Motor2::State.new)
    runner = Motor2::Runner.new(Motor2::Config.new(agent.reload), state: state, history: [])
    Motor2::Prompt.new(runner, Motor2::Skills.for(runner)).system
  end

  it 'el prompt trae el puesto, el negocio, sus preguntas tal cual y en orden, las objeciones y los datos a juntar' do
    save_agent(settings.merge('business_what' => 'Paneles solares', 'question_list' => ['¿Qué auto buscas?', '¿Es para tu familia?'],
                              'objections' => [{ 'objection' => 'Está caro', 'answer' => 'Se paga solo en 4 años' }],
                              'required_contact' => %w[email]), template: agent)

    expect(system_prompt).to include('ERES: el primer contacto', 'Qué vende: Paneles solares', 'TAL CUAL',
                                     "1. «¿Qué auto buscas?»\n2. «¿Es para tu familia?»",
                                     '«Está caro» → Se paga solo', 'DATOS OBLIGATORIOS', 'su correo', 'TEMPERATURA',
                                     'TE FALTA PREGUNTAR (en orden; la siguiente es la 1): 1, 2')
  end

  it 'los agentes de antes: sus preguntas armadas prendidas y las propias pasan a la lista' do
    save_agent(settings.merge('question_list' => [], 'questions' => 'qué busca y su ciudad',
                              'qualify' => [{ 'key' => 'need', 'on' => false }, { 'key' => 'budget', 'on' => true, 'text' => '' }]),
               template: agent)
    expect(system_prompt).to include("1. «¿Tienes un presupuesto aproximado?»\n2. «qué busca y su ciudad»")
  end

  it 'guarda cada respuesta con el número de la pregunta y lleva la cuenta de cuál sigue' do
    save_agent(settings.merge('question_list' => ['¿Qué auto buscas?', '¿Para cuándo?', '¿Presupuesto?']), template: agent)
    stub_model(tool_call('guardar_respuesta', { numero: 2, respuesta: 'mañana' }), tool_call('guardar_respuesta', { numero: 1, respuesta: 'sedán' }),
               answer('¡Va! ¿Tienes un presupuesto?'))
    reply_to(incoming('Un sedán, lo quiero para mañana'))

    expect(tracking.motor2_state['answers']).to eq('¿Para cuándo?' => 'mañana', '¿Qué auto buscas?' => 'sedán')
    expect(system_prompt(Motor2::State.new(tracking.motor2_state))).to include('TE FALTA PREGUNTAR (en orden; la siguiente es la 3): 3')
  end

  it 'el mensaje del cliente en su bandeja lo toma el motor 2.0 (sin automatización)' do
    expect { incoming('Hola, info') }.to have_enqueued_job(Motor2::ReplyJob)
    expect(ContactTrackingResponseAnalyzerJob).not_to have_been_enqueued
  end

  it 'contesta, guarda lo que el prospecto dijo y el seguimiento queda activo y sin intentos' do
    stub_model(tool_call('guardar_respuesta', { numero: 1, respuesta: 'Paneles solares' }),
               answer('¡Hola Mario! ¿En qué ciudad estás?'))
    reply_to(incoming('Busco paneles solares'))

    sent = conversation.messages.outgoing.where(private: false).last
    expect(sent.content).to eq('¡Hola Mario! ¿En qué ciudad estás?')
    expect(sent.content_attributes).to include('ai_agent' => true)
    expect(tracking).to have_attributes(status: 'active', tracking_template_id: agent.id, max_attempts: 1)
    expect(tracking.scheduled_for).to be > 1.year.from_now
    expect(tracking.motor2_state['answers']).to eq('¿Qué buscas?' => 'Paneles solares')
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

  it 'si dice su empresa y está en Organizaciones, liga el contacto' do
    org = account.organizations.create!(name: 'Ferretería Sol')
    stub_model(tool_call('actualizar_contacto', { empresa: 'ferretería sol' }), answer('¡Gracias! ¿Qué buscas?'))
    reply_to(incoming('soy de ferretería sol'))
    expect(contact.reload.organization).to eq(org)
  end

  it 'deja la etiqueta de cómo terminó (calificado, descartado…), además de «interesado» y la temperatura' do
    stub_model(tool_call('prospecto_calificado', { resumen: 'Lo quiere ya', temperatura: 'caliente' }), answer('¡Listo!'))
    reply_to(incoming('Lo necesito ya'))
    expect(conversation.reload.label_list).to include('calificado', 'interesado', 'prospecto-caliente')
  end

  it 'con temperatura, la nueva etiqueta reemplaza a la anterior' do
    conversation.update_labels(['prospecto-frio'])
    stub_model(tool_call('prospecto_calificado', { resumen: 'Lo quiere este mes', temperatura: 'caliente' }), answer('¡Listo!'))
    reply_to(incoming('Lo necesito ya y tengo el presupuesto'))

    expect(conversation.reload.label_list).to include('interesado', 'prospecto-caliente')
    expect(conversation.label_list).not_to include('prospecto-frio')
  end

  it 'lo que se supo queda en el contacto: temperatura (atributo filtrable) y sus respuestas' do
    stub_model(tool_call('prospecto_calificado', { resumen: 'Lo quiere este mes', temperatura: 'caliente' }), answer('¡Listo!'))
    reply_to(incoming('Lo necesito ya y tengo el presupuesto'))

    expect(contact.reload.custom_attributes).to include('temperatura_prospecto' => 'caliente')
    expect(contact.additional_attributes['calificacion']).to include('agente' => 'Prospectos Facebook', 'temperatura' => 'caliente')
    expect(account.custom_attribute_definitions.find_by(attribute_key: 'temperatura_prospecto')).to have_attributes(attribute_display_type: 'list')
  end

  it 'métricas: cómo terminan, el % que califica y en qué pregunta se van' do
    base = { account: account, inbox_id: inbox.id, tracking_template: agent, objective: 'Atender prospectos', max_attempts: 1,
             scheduled_for: 1.day.from_now }
    3.times do |i|
      conv = create(:conversation, account: account, inbox: inbox, contact: create(:contact, account: account),
                                   additional_attributes: { 'ad_referral' => { 'headline' => 'Camionetas 2019' } })
      ContactTracking.create!(base.merge(contact: conv.contact, conversation: conv, status: 'completed',
                                         motor2_state: { 'answers' => i.zero? ? { '¿Qué buscas?' => 'un sedán' } : {} }))
    end
    ContactTracking.create!(base.merge(contact: contact, conversation: conversation, status: 'objective_met', outcome: 'qualified: ok'))

    metrics = Motor2::ProspectMetrics.new(agent).call
    expect(metrics).to include(total: 4, conversion: 25)
    expect(metrics[:results]).to include('no_answer' => 3, 'qualified' => 1)
    expect(metrics[:drop_off]).to eq([{ question: '¿Qué buscas?', count: 2 }, { question: '¿En qué ciudad estás?', count: 1 }])
    expect(metrics[:ads]).to eq([{ headline: 'Camionetas 2019', total: 3, good: 0 }])
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

  it 'productos y precios: el catálogo entra a sus fuentes y se busca con buscar_en_fuentes (los de antes con la casilla también)' do
    account.catalog_items.create!(name: 'Pickup 2020', price: 320_000, active: true)
    names = lambda do
      runner = Motor2::Runner.new(Motor2::Config.new(agent.reload), state: Motor2::State.new, history: [])
      Motor2::Skills.for(runner).flat_map(&:tools).map { |t| t.dig(:function, :name) }
    end
    expect(names.call).to include('guardar_respuesta', 'prospecto_calificado', 'descartar', 'pasar_a_humano')
    expect(names.call).not_to include('buscar_en_catalogo', 'objetivo_cumplido', 'ver_horarios')

    save_agent(settings.merge('business_use_catalog' => true), template: agent) # agente de antes
    expect(Motor2::Config.new(agent.reload).sources).to include('catalog')
    expect(system_prompt).to include('SOLO en «Catálogo de productos»')

    found = Motor2::Search.new(account, ['catalog']).call('pickup', only: 'Catálogo de productos')
    expect(found.first[:resultados].first).to include(titulo: 'Pickup 2020', informacion: include('Precio: $320,000'))
  end

  it 'productos y precios: «no doy precios» lo dice un asesor' do
    save_agent(settings.merge('price_source' => 'none'), template: agent)
    expect(system_prompt).to include('Precios: NO los das')
    expect(Motor2::Config.new(agent.reload).sources).not_to include('catalog')
  end

  context 'with objetivo «juntar sus datos»' do
    let(:objective) { 'collect' }

    it 'al guardar la última respuesta se entera de que terminó y lo califica: nota, etiqueta y se asigna' do
      stub_model(tool_call('guardar_respuesta', { numero: 1, respuesta: 'sedán' }), tool_call('guardar_respuesta', { numero: 2, respuesta: 'GDL' }),
                 tool_call('prospecto_calificado', { resumen: 'Sedán en GDL', temperatura: 'tibio' }), answer('¡Gracias! Ana te escribe.'))
      reply_to(incoming('Busco un sedán, estoy en GDL'))

      last_tool = tracking.motor2_state['answers']
      expect(last_tool).to eq('¿Qué buscas?' => 'sedán', '¿En qué ciudad estás?' => 'GDL')
      expect(conversation.reload.label_list).to include('interesado', 'prospecto-tibio')
      expect(conversation.assignee_id).to eq(seller.id)
      expect(tracking.status).to eq('objective_met')
    end

    it 'guardar_respuesta le dice cuál sigue o que ya terminó' do
      runner = Motor2::Runner.new(Motor2::Config.new(agent), state: Motor2::State.new, history: [])
      qualify = Motor2::Skills.for(runner).find { |s| s.key == 'qualify' }
      qualify.prepare([])
      expect(qualify.call('guardar_respuesta', { 'numero' => 1, 'respuesta' => 'sedán' })).to include(siguiente: '2. ¿En qué ciudad estás?')
      expect(qualify.call('guardar_respuesta', { 'numero' => 2, 'respuesta' => 'GDL' })[:nota]).to include('YA CONTESTÓ TODAS')
    end
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

  context 'with mensaje de bienvenida' do
    before { save_agent(settings.merge('welcome' => '¡Hola! Soy Ana de Autos GDL 🚗'), template: agent) }

    it 'va tal cual al inicio de su primera respuesta, en el mismo mensaje, y solo una vez' do
      stub_model(answer('Con gusto te ayudo. ¿Qué buscas?'))
      reply_to(incoming('¿Precio del sedán?'))

      expect(conversation.messages.outgoing.where(private: false).count).to eq(1)
      expect(conversation.messages.outgoing.where(private: false).last.content)
        .to eq("¡Hola! Soy Ana de Autos GDL 🚗\n\nCon gusto te ayudo. ¿Qué buscas?")
      expect(tracking.motor2_state['welcome_sent']).to be(true)

      stub_model(tool_call('guardar_respuesta', { numero: 1, respuesta: 'un sedán' }), answer('¡Perfecto! ¿En qué ciudad estás?'))
      reply_to(incoming('un sedán'))
      expect(conversation.messages.outgoing.where(private: false).last.content).to eq('¡Perfecto! ¿En qué ciudad estás?')
    end

    it 'si el modelo la repite con otros espacios o signos, igual sale una sola vez' do
      stub_model(answer('¡Hola!   Soy Ana de Autos GDL 🚗 ¿Qué buscas?'))
      reply = Motor2::Probe.new(agent.reload, messages: [{ role: 'user', content: 'buen día, info' }]).call[:reply]
      expect(reply).to eq("¡Hola! Soy Ana de Autos GDL 🚗\n\n¿Qué buscas?")
    end

    it 'si la bienvenida ya pregunta y el cliente solo saludó, no lleva otra pregunta' do
      save_agent(settings.merge('welcome' => '¡Hola! Soy Ana, ¿en qué te ayudo?'), template: agent)
      stub_model(answer('¡Hola! Soy Ana, ¿en qué te ayudo? ¿Qué buscas?'))
      reply = Motor2::Probe.new(agent.reload, messages: [{ role: 'user', content: 'hola' }]).call[:reply]
      expect(reply).to eq('¡Hola! Soy Ana, ¿en qué te ayudo?')
    end

    it 'en el chat de prueba también: solo en la primera respuesta' do
      stub_model(answer('¿Qué buscas?'))
      first = Motor2::Probe.new(agent.reload, messages: [{ role: 'user', content: 'hola' }]).call
      expect(first[:reply]).to eq("¡Hola! Soy Ana de Autos GDL 🚗\n\n¿Qué buscas?")

      later = Motor2::Probe.new(agent, messages: [{ role: 'user', content: 'hola' }, { role: 'assistant', content: first[:reply] },
                                                  { role: 'user', content: 'un sedán' }]).call
      expect(later[:reply]).not_to include('Soy Ana')
    end
  end

  it 'si el cliente pregunta algo y contesta sin buscar, se le pide que busque antes de afirmarlo' do
    create(:canned_response, account: account, short_code: 'Horario', content: 'Abrimos de 9 a 6')
    stub_model(answer('Sí, abrimos el domingo. ¿Qué buscas?'), tool_call('buscar_en_fuentes', { pregunta: 'horario domingo' }),
               answer('Abrimos de 9 a 6 entre semana; un asesor te confirma el domingo. ¿Qué buscas?'))
    allow_any_instance_of(AiFollowUps::KnowledgeSearch).to receive(:canned).and_return({ results: [] }) # rubocop:disable RSpec/AnyInstance
    result = Motor2::Probe.new(agent, messages: [{ role: 'user', content: '¿abren el domingo?' }]).call

    expect(result[:reply]).to include('un asesor te confirma')
    expect(result[:trace]['events']).to include(include('text' => 'contestó sin buscar'))
  end

  context 'with «Cómo platica»' do
    it 'por omisión: contesta dudas, si no encuentra un asesor lo confirma, fuera de tema lo regresa, persona: terminar primero' do
      expect(system_prompt).to include('CÓMO PLATICAS', 'contéstale con lo que encuentres', 'un asesor se lo confirma',
                                       'regrésalo con', 'solo te faltan unas preguntas', 'termina tu mensaje con la pregunta 1')
      expect(agent.motor2['answers']).to include('doubts' => 'answer', 'not_found' => 'advisor', 'off_topic' => 'redirect',
                                                 'human' => 'finish_first')
    end

    it 'si no contesta dudas, no tiene con qué buscar y «no encontró» y «fuera de tema» no aplican' do
      create(:canned_response, account: account, short_code: 'Precios', content: 'Desde $100')
      save_agent(settings.merge('doubts' => 'defer', 'business_use_catalog' => true, 'off_topic' => 'answer'), template: agent)
      runner = Motor2::Runner.new(Motor2::Config.new(agent.reload), state: Motor2::State.new, history: [])
      names = Motor2::Skills.for(runner).flat_map(&:tools).map { |t| t.dig(:function, :name) }

      expect(names).not_to include('buscar_en_fuentes', 'buscar_en_catalogo')
      expect(system_prompt).to include('NO contestas dudas')
      expect(system_prompt).not_to include('Si buscas y no encuentras', 'contéstale con amabilidad en 1 o 2 líneas')
    end

    it 'las otras opciones; y las de antes («lo pasa», «lo descarta») pasan a las recomendadas' do
      save_agent(settings.merge('not_found' => 'silent', 'off_topic' => 'answer', 'human' => 'now'), template: agent)
      expect(system_prompt).to include('No prometas que un asesor', 'contéstale con amabilidad en 1 o 2 líneas', 'pásalo de inmediato')

      save_agent(settings.merge('not_found' => 'handoff', 'off_topic' => 'discard', 'doubts' => 'raro'), template: agent)
      expect(agent.reload.motor2['answers']).to include('doubts' => 'answer', 'not_found' => 'advisor', 'off_topic' => 'redirect')
    end
  end

  context 'with «pide hablar con una persona»' do
    let(:settings) do
      { 'objective' => 'handoff', 'handoff_user_id' => seller.id,
        'question_list' => ['¿Qué buscas?', '¿Para cuándo?', '¿Presupuesto?', '¿Ciudad?'] }
    end

    let(:memory) { {} }

    def probe(*customer)
      chat = customer.each_with_index.flat_map do |text, i|
        [{ role: 'user', content: text }, ({ role: 'assistant', content: '¿Qué buscas?' } if i < customer.size - 1)].compact
      end
      Motor2::Probe.new(agent.reload, messages: chat, state: memory[:state] || {}).call.tap { |r| memory[:state] = r[:state] }
    end

    it 'terminar primero: solo pide las que faltan (máx. 2) con la frase que conecta; si insiste, lo pasa ya' do
      stub_model(answer('Claro, con gusto. ¿Qué buscas?'))
      first = probe('quiero hablar con un asesor')
      expect(first[:state]['human_pending']).to eq([1, 2])
      expect(first[:decision]).to be_nil

      stub_model(answer('Te paso en un momento, ¿qué buscas?'))
      second = probe('quiero hablar con un asesor', 'ya te dije, pásame con una persona')
      expect(second[:decision]).to eq(['handoff', 'Pidió hablar con una persona.'])
      expect(second[:reply]).to eq(Motor2::ReplyChecks::HANDOFF_TEXT)
    end

    it 'de inmediato: lo pasa a la primera' do
      save_agent(settings.merge('human' => 'now'), template: agent)
      stub_model(tool_call('pasar_a_humano', { motivo: 'Pidió una persona' }), answer('En un momento te atiende un asesor.'))
      result = probe('¿me pasas con un humano?')
      expect(result[:decision].first).to eq('handoff')
    end

    it 'si en el mismo turno intenta pasarlo dos veces, se detienen las dos (la primera vez que lo pide)' do
      stub_model(tool_call('pasar_a_humano', { motivo: 'x' }), tool_call('pasar_a_humano', { motivo: 'x' }), answer('Claro. ¿Qué buscas?'))
      result = probe('pasame con un humano')
      expect(result[:decision]).to be_nil
      expect(result[:trace]['tools'].pluck('ok')).to eq([false, false])
    end

    it 'la segunda vez lo pasa aunque lo escriba con errores' do
      stub_model(answer('Claro. ¿Qué buscas?'))
      probe('pasame con un humano')
      stub_model(answer('Te paso.'))
      expect(probe('pasame con un humano', 'pasme con un humano')[:decision].first).to eq('handoff')
    end

    it 'una duda sin «?» («das financiamiento…») no se guarda como respuesta y retoma conectando' do
      stub_model(tool_call('guardar_respuesta', { numero: 1, respuesta: 'das financiamiento con banamex' }),
                 tool_call('buscar_en_fuentes', { pregunta: 'financiamiento' }), answer('No tengo ese dato.'))
      result = probe('hola', 'das financiamiento con banamex')
      expect(result[:state]['answers'].to_h).to be_empty
      expect(result[:reply]).to match(/#{neutral}/) # sin «me faltan 4 preguntas»: suena a encuesta
    end

    it 'con «no encontró → sin prometer asesor», se quita la promesa aunque el modelo insista' do
      save_agent(settings.merge('not_found' => 'silent'), template: agent)
      stub_model(tool_call('buscar_en_fuentes', { pregunta: 'financiamiento' }),
                 answer('No tengo ese dato, pero un asesor te lo confirma. ¿Qué buscas?'))
      result = probe('¿dan financiamiento?')
      expect(result[:reply]).to start_with('No tengo ese dato.')
      expect(result[:reply]).not_to include('asesor')
      expect(result[:trace]['events']).to include(include('text' => 'prometió un asesor (eligieron no hacerlo)'))
    end

    it 'una objeción o algo de otro tema no se guarda como respuesta (AnswerCheck) y la pregunta se retoma conectando' do
      allow_any_instance_of(Motor2::AnswerCheck).to receive(:answers?).and_return(false) # rubocop:disable RSpec/AnyInstance
      stub_model(tool_call('guardar_respuesta', { numero: 1, respuesta: 'no me gusta el color' }), answer('El morado es muy bonito.'))
      result = probe('hola', 'no me gusta el color')

      expect(result[:state]['answers'].to_h).to be_empty
      expect(result[:reply]).to match(/El morado es muy bonito\.\n\n#{neutral}\n\n¿Qué buscas\?/m)
    end

    it 'en el primer mensaje no hay frase para retomar (no hay nada que retomar)' do
      stub_model(answer('Abrimos de 9 a 6.'))
      expect(probe('¿a qué hora abren?')[:reply]).to eq("Abrimos de 9 a 6.\n\n¿Qué buscas?")
    end

    it 'al retomar después de una duda, la pregunta va con la frase que conecta' do
      stub_model(answer('Abrimos de 9 a 6.'))
      result = probe('hola', '¿a qué hora abren?')
      expect(result[:reply]).to match(/Abrimos de 9 a 6\.\n\n#{neutral}\n\n¿Qué buscas\?/m)
    end
  end

  it 'lo que ya dijo de pasada lo guarda el código (Motor2::AnswerExtractor) y no se le vuelve a preguntar' do
    allow_any_instance_of(Motor2::AnswerExtractor).to receive(:call).and_return({ 1 => 'una camioneta familiar' }) # rubocop:disable RSpec/AnyInstance
    stub_model(answer('Con gusto. ¿Qué buscas?'), answer('Con gusto. ¿En qué ciudad estás?'))
    result = Motor2::Probe.new(agent.reload, messages: [{ role: 'user', content: 'busco una camioneta familiar, ¿qué precio tienen?' }]).call

    expect(result[:state]['answers']).to eq('¿Qué buscas?' => 'una camioneta familiar')
    expect(result[:reply]).to end_with('¿En qué ciudad estás?')
    expect(result[:trace]['events']).to include(include('text' => '¿Qué buscas?: una camioneta familiar (de la plática)'))
  end

  it 'una pregunta con «[solo si …]» lleva su condición y se hace sin ella' do
    conditional = save_agent(settings.merge('question_list' => ['¿Qué buscas?', '¿Cuántos empleados tienen? [solo si es empresa]']),
                             template: agent)
    questions = Motor2::Config.new(conditional.reload).function.questions
    expect(questions.last).to eq(number: 2, ask: '¿Cuántos empleados tienen?', condition: 'es empresa')
  end

  describe 'cotizar' do
    before do
      account.case_types.create!(name: 'Ventas', case_class: :commercial)
      account.catalog_items.create!(name: 'Panel solar 550W', price: 4200, kind: :product)
    end

    it 'cotiza en cuanto la pide (sin terminar las preguntas) y eso lo califica, caliente, sin abrir otra oportunidad' do
      save_agent(settings.merge('objective' => 'opportunity', 'quote' => { 'mode' => 'draft' }), template: agent)
      stub_model(tool_call('cotizar', { partidas: [{ producto: 'panel solar', cantidad: 10 }] }), answer('Tu asesor te la manda en un momento.'))
      reply_to(incoming('cotízame 10 paneles solares'))

      quote = account.quotes.last
      expect(quote.items.first).to have_attributes(quantity: 10, unit_price: 4200)
      expect(tracking.reload).to have_attributes(status: 'objective_met', outcome: "qualified: Cotización #{quote.folio}")
      expect(tracking.motor2_state['temperature']).to eq('caliente')
      expect(CaseTicket.where(contact: contact).count).to eq(1) # la de la cotización, no otra
      expect(conversation.reload).to have_attributes(assignee_id: seller.id)
      expect(conversation.label_list).to include('interesado', 'prospecto-caliente', 'cotizacion')
    end

    it 'en borrador, el seguimiento de la cotización empieza cuando el vendedor la manda; pasadas 24 h usa SU plantilla' do
      save_agent(settings.merge('quote' => { 'mode' => 'draft', 'follow_days' => 2, 'template' => 'pregunta_cotizacion' }), template: agent)
      stub_model(tool_call('cotizar', { partidas: [{ producto: 'panel solar', cantidad: 1 }] }), answer('Tu asesor te la manda.'))
      expect { reply_to(incoming('cotízame un panel')) }.not_to have_enqueued_job(Motor2::QuoteFollowUpJob)

      quote = account.quotes.last
      expect { Quotes::Delivery.new(quote, seller).deliver! }.to have_enqueued_job(Motor2::QuoteFollowUpJob).with(tracking.id, quote.id)

      expect(Motor2::LateMessage).to receive(:deliver).with(anything, anything, template: 'pregunta_cotizacion').and_return(nil)
      travel(3.days) { Motor2::QuoteFollowUpJob.perform_now(tracking.id, quote.id) }
      expect(note).to include('no se le pudo preguntar', quote.folio) # el vendedor sabe que no le llegó
    end

    it 'no le pregunta por la cotización si ya escribió después de recibirla, ni si se apagó la opción' do
      save_agent(settings.merge('quote' => { 'mode' => 'send', 'follow' => false }), template: agent)
      stub_model(tool_call('cotizar', { partidas: [{ producto: 'panel solar', cantidad: 1 }] }), answer('Ya te la mandé.'))
      expect { reply_to(incoming('cotízame un panel')) }.not_to have_enqueued_job(Motor2::QuoteFollowUpJob)

      quote = account.quotes.last
      travel(1.minute) { incoming('gracias, la reviso') }
      expect(Motor2::LateMessage).not_to receive(:deliver)
      Motor2::QuoteFollowUpJob.perform_now(tracking.id, quote.id)
    end

    it 'antes de cotizar pide los datos obligatorios' do
      save_agent(settings.merge('quote' => { 'mode' => 'draft' }, 'required_contact' => %w[email]), template: agent)
      stub_model(tool_call('cotizar', { partidas: [{ producto: 'panel solar', cantidad: 1 }] }), answer('¿Me compartes tu correo?'))
      reply_to(incoming('cotízame un panel'))
      expect(account.quotes.count).to eq(0)
    end
  end

  describe 'recomendar del Catálogo' do
    let(:settings) do
      { 'objective' => 'handoff', 'question_list' => ['¿Qué buscas?'], 'handoff_user_id' => seller.id, 'price_source' => 'catalog' }
    end

    def item(name, price, photo: false)
      account.catalog_items.create!(name: name, price: price, kind: :product, description: 'Camioneta familiar').tap do |it|
        it.image.attach(io: Rails.root.join('spec/assets/sample.png').open, filename: 'foto.png', content_type: 'image/png') if photo
      end
    end

    it 'propone hasta 3 que le alcancen, con su precio, y manda sus fotos; no repite lo ya recomendado' do
      item('Camioneta Tiguan 2019', 239_000, photo: true)
      item('Camioneta CRV 2018', 245_000)
      item('Camioneta Suburban 2021', 690_000)
      stub_model(tool_call('recomendar', { lo_que_busca: 'camioneta familiar', presupuesto: 250_000 }),
                 answer('Te propongo la Tiguan 2019 en $239,000 y la CRV 2018 en $245,000. ¿Qué buscas?'))
      result = Motor2::Probe.new(agent.reload, messages: [{ role: 'user', content: 'busco camioneta, tengo 250 mil' }]).call

      expect(result[:state]['recomendados'].size).to eq(2) # la Suburban no le alcanza
      expect(result[:files]).to eq(['Camioneta Tiguan 2019'])
      expect(result[:reply]).to include('$239,000')
    end

    it 'solo con los precios en el Catálogo (si no, no tiene la herramienta)' do
      expect(Motor2::Config.new(agent.reload).skill_on?('recommend')).to be(true)
      save_agent(settings.merge('price_source' => 'canned'), template: agent)
      expect(Motor2::Config.new(agent.reload).skill_on?('recommend')).to be(false)
    end
  end

  describe 'archivos con la bienvenida' do
    let(:settings) do
      { 'objective' => 'handoff', 'question_list' => ['¿Qué buscas?'], 'handoff_user_id' => seller.id, 'welcome' => '¡Hola! Soy Sofi.' }
    end

    it 'van junto con la bienvenida combinada (también en «Probar», con su miniatura) y no se repiten' do
      create(:ai_agent_attachment, tracking_template: agent, name: 'promo',
                                   file: fixture_file_upload(Rails.root.join('spec/assets/sample.png'), 'image/png'))
      agent.update!(resources: { 'files' => { 'promo' => { 'welcome' => true, 'ask' => false } } })
      stub_model(answer('¿Qué buscas?'))

      result = Motor2::Probe.new(agent.reload, messages: [{ role: 'user', content: 'hola' }]).call
      expect(result[:reply]).to start_with('¡Hola! Soy Sofi.')
      expect(result[:files]).to eq(['promo'])
      expect(result[:previews].first).to include(name: 'promo', image: true)

      reply_to(incoming('hola'))
      expect(conversation.messages.outgoing.last.attachments.size).to eq(1)
      reply_to(incoming('busco camioneta'))
      expect(conversation.messages.outgoing.last.attachments.size).to eq(0)
    end
  end

  describe 'después de pasarlo o agendarlo' do
    it 'al pasarlo arranca el reloj: si nadie le escribe a tiempo, se avisa (TrackingCampaigns::HandoffSweepJob)' do
      save_agent(settings.merge('attend_hours' => 1), template: agent)
      stub_model(tool_call('pasar_a_humano', { motivo: 'Quiere hablar con alguien' }), answer('En un momento te atiende Ana.'))
      reply_to(incoming('quiero hablar con alguien ya'))
      reply_to(incoming('pásame con una persona'))

      expect(tracking.reload).to have_attributes(status: 'paused')
      expect(tracking.handed_off_at).to be_present
      expect(tracking.handoff_due_at).to be > tracking.handed_off_at
      TrackingCampaigns::HandoffSweepJob.new.perform(tracking.handoff_escalate_at + 1.minute)
      expect(conversation.messages.where(private: true).pluck(:content).join).to include('⏰', '🚨', 'Prospectos Facebook')
    end

    it 'recordatorio de la cita: con día, hora y con quién; si la movieron, el aviso viejo no sale' do
      stub_model(answer('¿Qué buscas?'))
      reply_to(incoming('hola'))
      meeting = instance_double(CaseMeeting, starts_at: Time.zone.parse('2026-11-27 10:00'), organizer: seller,
                                             scheduled?: true, rescheduled?: false, no_show?: false)
      Motor2::AppointmentNotice.deliver(tracking, meeting, 'reminder')

      expect(conversation.messages.outgoing.where(private: false).last.content)
        .to include('¡Hola Mario!', 'Te recuerdo tu cita', '10:00', 'con Ana', '¿Nos confirmas')
      expect(Motor2::AppointmentNotice.due?(meeting, 'reminder', meeting.starts_at.iso8601)).to be(true)
      expect(Motor2::AppointmentNotice.due?(meeting, 'reminder', 1.day.ago.iso8601)).to be(false)
      expect(Motor2::AppointmentNotice.due?(meeting, 'no_show', meeting.starts_at.iso8601)).to be(false)
    end
  end

  describe 'si deja de contestar' do
    let(:settings) do
      { 'objective' => 'handoff', 'question_list' => ['¿Qué buscas?', '¿En qué ciudad estás?'], 'handoff_user_id' => seller.id,
        'follow_up' => { 'nudges' => 2, 'templates' => ['seguimiento_1'], 'template_days' => 2 } }
    end

    it 'sin recordatorios guardados (agentes de antes) no se programa nada' do
      save_agent(settings.except('follow_up'), template: agent)
      stub_model(answer('¿En qué ciudad estás?'))
      expect { reply_to(incoming('Busco paneles')) }.not_to have_enqueued_job(Motor2::FollowUpJob)
    end

    it 'después de contestarle, programa el recordatorio a las 2 horas de su mensaje' do
      stub_model(answer('¿En qué ciudad estás?'))
      message = incoming('Busco paneles')
      expect { reply_to(message) }.to have_enqueued_job(Motor2::FollowUpJob).with(kind_of(Integer), message.id, 0)
                                                                            .at(a_value_within(1.second).of(message.created_at + 2.hours))
      expect(tracking.motor2_state).to include('follow_up' => true, 'follow_up_message' => message.id)
    end

    it 'el recordatorio retoma la plática si sigue sin contestar; si ya contestó, no' do
      stub_model(answer('¿En qué ciudad estás?'))
      message = incoming('Busco paneles')
      reply_to(message)
      allow_any_instance_of(Motor2::Attempt).to receive(:message).and_return('¿Pudiste ver lo de tu ciudad?') # rubocop:disable RSpec/AnyInstance

      expect { Motor2::FollowUpJob.perform_now(tracking.id, message.id, 0) }
        .to change { conversation.messages.outgoing.where(private: false).count }.by(1)
        .and have_enqueued_job(Motor2::FollowUpJob).with(tracking.id, message.id, 1)
      incoming('en Monterrey')
      expect { Motor2::FollowUpJob.perform_now(tracking.id, message.id, 1) }.not_to(change { conversation.messages.outgoing.count })
    end

    it 'después de los recordatorios van las plantillas (24 h después de su mensaje, una cada N días)' do
      stub_model(answer('¿En qué ciudad estás?'))
      message = incoming('Busco paneles')
      reply_to(message)
      allow(Motor2::FollowUp).to receive(:whatsapp?).and_return(true)
      Motor2::FollowUp.next_step(tracking, message, 2, Motor2::Config.new(agent.reload).function.follow_up)

      expect(tracking.reload).to have_attributes(status: 'scheduled', whatsapp_templates: ['seguimiento_1'], max_attempts: 1,
                                                 retry_interval_value: 2, retry_interval_unit: 'days')
      expect(tracking.scheduled_for).to be_within(1.minute).of(message.created_at + 3.days)
    end

    it 'si el recordatorio llega tarde (ventana cerrada) no manda texto libre: sigue con las plantillas, o cierra sin ellas' do
      stub_model(answer('¿En qué ciudad estás?'))
      message = incoming('Busco paneles')
      reply_to(message)
      allow(Motor2::LateMessage).to receive(:window_open?).and_return(false)
      allow(Motor2::FollowUp).to receive(:whatsapp?).and_return(true)

      expect { Motor2::FollowUpJob.perform_now(tracking.id, message.id, 1) }.not_to(change do
                                                                                      conversation.messages.outgoing.where(private: false).count
                                                                                    end)
      expect(tracking.reload).to have_attributes(status: 'scheduled', whatsapp_templates: ['seguimiento_1'])

      save_agent(settings.merge('follow_up' => { 'nudges' => 2, 'templates' => [] }), template: agent)
      tracking.update_columns(status: 'active', motor2_state: tracking.motor2_state.merge('follow_up_message' => message.id)) # rubocop:disable Rails/SkipsModelValidations
      Motor2::FollowUpJob.perform_now(tracking.id, message.id, 1)
      expect(conversation.reload.label_list).to include('sin-respuesta')
    end

    it 'en WhatsApp deja una hora de margen antes de que cierre la ventana de 24 h' do
      wa = create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false).inbox
      chat = create(:conversation, account: account, inbox: wa, contact: contact)
      last = create(:message, account: account, inbox: wa, conversation: chat, message_type: :incoming, content: 'hola', sender: contact)
      last.update_columns(created_at: 22.hours.ago) # rubocop:disable Rails/SkipsModelValidations
      expect(Motor2::LateMessage.window_open?(chat.reload)).to be(true)
      last.update_columns(created_at: 23.5.hours.ago) # rubocop:disable Rails/SkipsModelValidations
      expect(Motor2::LateMessage.window_open?(chat.reload)).to be(false)
    end

    it 'si contesta después del último toque, el agente lo retoma' do
      stub_model(answer('¿En qué ciudad estás?'))
      reply_to(incoming('Busco paneles'))
      tracking.update_columns(status: 'completed') # rubocop:disable Rails/SkipsModelValidations

      stub_model(answer('¡Perfecto! Te paso con Ana.'))
      reply_to(incoming('perdón, estoy en Monterrey'))
      expect(tracking.reload.status).to eq('active')
      expect(conversation.messages.outgoing.where(private: false).last.content).to include('Perfecto')
    end
  end

  it 'lo que corrige el entrenador cae en «Indicaciones» (lo único de texto libre que enseña el asistente)' do
    cause = { 'kind' => 'agent', 'field' => 'never', 'replace' => 'Nunca prometas descuentos.', 'summary' => 'Sin descuentos' }
    Motor2::Trainer::AgentFix.new(agent, admin, cause).call

    expect(agent.reload.motor2['instructions']).to include('Nunca prometas descuentos.')
    expect(agent.motor2['never'].to_s).to be_empty
    expect(agent.motor2['answers']).to include('objective' => 'handoff')
  end

  it 'chat de prueba: contesta con el motor 2.0 sin guardar ni mandar nada' do
    stub_model(tool_call('guardar_respuesta', { numero: 2, respuesta: 'Monterrey' }), answer('¡Perfecto! ¿Qué buscas?'))
    result = nil
    expect { result = Motor2::Probe.new(agent, messages: [{ role: 'user', content: 'Soy de Monterrey' }]).call }
      .not_to change(ContactTracking, :count)

    expect(result).to include(reply: '¡Perfecto! ¿Qué buscas?')
    expect(result[:state]['answers']).to eq('¿En qué ciudad estás?' => 'Monterrey')
  end

  context 'with la secuencia de preguntas (la manda el código)' do
    let(:chat) do
      [{ role: 'user', content: 'hola' }, { role: 'assistant', content: '¡Hola! ¿Qué buscas?' }, { role: 'user', content: 'un sedán' }]
    end

    it 'le dice que acaba de contestar la pregunta que hizo (para que la guarde) y con cuál terminar' do
      replies = [tool_call('guardar_respuesta', { numero: 1, respuesta: 'un sedán' }), answer('¡Muy bien! ¿En qué ciudad estás?')]
      sent = []
      allow_any_instance_of(Motor2::Runner).to receive(:complete) do |_runner, messages| # rubocop:disable RSpec/AnyInstance
        sent << messages.last[:content].to_s
        replies.shift
      end
      result = Motor2::Probe.new(agent, messages: chat).call

      expect(sent.first).to include('Le preguntaste 1. «¿Qué buscas?»', 'guardar_respuesta numero 1', 'tal cual: «¿Qué buscas?»')
      expect(result[:state]['answers']).to eq('¿Qué buscas?' => 'un sedán')
      expect(result[:reply]).to eq('¡Muy bien! ¿En qué ciudad estás?')
    end

    it 'si no termina con la pendiente, se la pide; si tampoco, cambia su pregunta por la pendiente (nunca dos)' do
      stub_model(answer('¡Muy bien! ¿Tienes algún modelo en mente?'))
      result = Motor2::Probe.new(agent, messages: chat).call

      expect(result[:reply]).to match(/\A¡Muy bien!\n\n(Ya casi terminamos|Para avanzar)[,:] solo me faltan 2 preguntas\.\n\n¿Qué buscas\?\z/)
      expect(result[:trace]['events']).to include(include('kind' => 'revision', 'text' => 'pregunta pendiente'))
    end
  end
end
