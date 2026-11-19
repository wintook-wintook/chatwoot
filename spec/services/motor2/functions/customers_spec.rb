# frozen_string_literal: true

require 'rails_helper'

# Función «Atención a clientes» sobre el motor 2.0 (Plan-Motor-Agentes §11.15). OpenAI no se llama:
# se simulan el clasificador (Motor2::Triage), la revisión de evidencia y las respuestas del modelo.
RSpec.describe Motor2::Functions::Customers do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator, name: 'John') }
  let(:support_user) { create(:user, account: account, role: :agent, name: 'Sara Soporte') }
  let(:billing_user) { create(:user, account: account, role: :agent, name: 'Ana Cobranza') }
  let(:seller) { create(:user, account: account, role: :agent, name: 'Víctor Ventas') }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Mario Pérez') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, assignee: nil) }
  let(:areas) do
    { 'support' => { 'on' => true, 'user_id' => support_user.id }, 'admin' => { 'on' => true, 'user_id' => billing_user.id },
      'sales' => { 'on' => true, 'user_id' => seller.id, 'quote' => 'opportunity' } }
  end
  let(:settings) { { 'business_what' => 'Software de facturación', 'areas' => areas } }
  let!(:agent) { save_agent(settings) }

  def save_agent(answers, template: nil, kind: 'customers', name: 'Clientes')
    Motor2::Functions::Form.new(account, { kind: kind, name: name, enabled: true, inbox_ids: [inbox.id], settings: answers },
                                user: admin, template: template).save
  end

  def tool_call(name, args)
    { 'role' => 'assistant', 'content' => nil,
      'tool_calls' => [{ 'id' => "call_#{name}", 'type' => 'function', 'function' => { 'name' => name, 'arguments' => args.to_json } }] }
  end

  def answer(text) = { 'role' => 'assistant', 'content' => text }

  def stub_model(*replies)
    allow_any_instance_of(Motor2::Runner).to receive(:complete).and_return(*replies) # rubocop:disable RSpec/AnyInstance
  end

  def triage(area, **extra)
    result = { 'atender' => { 'area' => area, 'intencion' => extra.delete(:intencion) || 'algo', 'suficiente' => true }.merge(extra.stringify_keys),
               'pendientes' => [] }
    allow_any_instance_of(Motor2::Triage).to receive(:call).and_return(result) # rubocop:disable RSpec/AnyInstance
  end

  def incoming(text)
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming, content: text, sender: contact)
  end

  def reply_to(message) = Motor2::ReplyJob.perform_now(message.id)

  def tracking = ContactTracking.find_by(conversation_id: conversation.id)

  def tools_for(state = Motor2::State.new, history = [{ role: 'user', content: 'hola' }])
    runner = Motor2::Runner.new(Motor2::Config.new(agent.reload), state: state, history: history)
    skills = Motor2::Skills.for(runner)
    runner.instance_variable_set(:@skills, skills)
    skills.each { |s| s.prepare(history) }
    skills.flat_map(&:tools).map { |t| t.dig(:function, :name) }
  end

  before do
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' })
    allow_any_instance_of(Motor2::AnswerCheck).to receive_messages(answers?: true, about_business?: true) # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(Motor2::EvidenceCheck).to receive(:call).and_return({ 'veredicto' => 'EXACTA', 'falta' => '' }) # rubocop:disable RSpec/AnyInstance
  end

  it 'se guarda como agente 2.0 de «Atención a clientes» con las áreas de la matriz ya llenas' do
    expect(agent).to have_attributes(engine: '2', agent_function: 'customers', attending: true)
    saved = agent.motor2.dig('answers', 'areas')
    expect(saved['support']).to include('on' => true, 'action' => 'case', 'examples_yes' => include('No puedo enviar una cotización a pedido'))
    expect(saved['sales']).to include('quote' => 'opportunity', 'examples_no' => include('La cotización no se genera'))
    expect(saved['other']).to include('on' => false)
  end

  it 'cada área trae solo sus herramientas; Administrativo no busca en las fuentes y Finish no aplica' do
    create(:canned_response, account: account, short_code: 'horario', content: 'De 9 a 6')
    triage('admin')
    expect(tools_for).to include('canalizar', 'estado_caso')
    expect(tools_for).not_to include('buscar_en_fuentes', 'registrar_gestion', 'objetivo_cumplido', 'descartar', 'pasar_a_humano')
    triage('sales', gestion: 'info')
    expect(tools_for).to include('buscar_en_fuentes', 'registrar_gestion', 'canalizar')
    expect(tools_for).not_to include('crear_caso')
    triage('support')
    expect(tools_for).to include('buscar_en_fuentes', 'crear_caso')
  end

  it 'si falta aclarar: no busca, hace una sola pregunta y la recuerda para el siguiente mensaje (continuidad)' do
    create(:canned_response, account: account, short_code: 'horario', content: 'De 9 a 6')
    triage('sales', suficiente: false, aclaracion: '¿Qué deseas cotizar?', intencion: 'cotización', gestion: 'cotizacion')
    state = Motor2::State.new
    expect(tools_for(state)).not_to include('buscar_en_fuentes')
    expect(state['pendiente']).to include('area' => 'sales', 'aclaracion' => '¿Qué deseas cotizar?')
  end

  it 'si ya se le pidió aclarar y contestó, no pregunta otra vez: busca con lo que hay' do
    create(:canned_response, account: account, short_code: 'horario', content: 'De 9 a 6')
    triage('none', suficiente: false, aclaracion: '¿En qué sistema?', intencion: 'dar de alta un cliente')
    state = Motor2::State.new
    tools_for(state)
    expect(state['pendiente']).to include('intencion' => 'dar de alta un cliente')

    expect(tools_for(state)).to include('buscar_en_fuentes') # sigue «falta aclarar», pero ya se aclaró una vez
    expect(state['triage']).to include('suficiente' => true)
  end

  it 'Soporte: no lo pasa ni levanta el caso sin antes buscar la solución en sus fuentes' do
    create(:canned_response, account: account, short_code: 'alta', content: 'Para dar de alta un cliente ve a Catálogos › Clientes.')
    triage('support', intencion: 'dar de alta un cliente', severidad: 3)
    stub_model(tool_call('canalizar', { motivo: 'alta de cliente' }), answer('Te paso con soporte.'))
    reply_to(incoming('cómo doy de alta un cliente'))

    tools = conversation.messages.outgoing.where(private: false).last.content_attributes.dig('motor2', 'tools')
    expect(tools.first).to include('name' => 'canalizar', 'ok' => false)
    expect(tracking.reload.status).to eq('active') # no se pasó
  end

  it 'Administrativo: canaliza al equipo de esa área, con nota, y el agente se pausa' do
    triage('admin', intencion: 'corregir RFC de una factura')
    stub_model(tool_call('canalizar', { motivo: 'Corregir el RFC de la factura A-1' }),
               answer('Le paso tu solicitud a nuestro equipo administrativo, en cuanto puedan te atienden.'))
    reply_to(incoming('Mi factura tiene mal el RFC'))

    expect(conversation.reload.assignee_id).to eq(billing_user.id)
    expect(tracking.reload.status).to eq('paused')
    expect(conversation.messages.where(private: true).last.content).to include('Administrativo', 'RFC')
  end

  it 'Soporte: pregunta primero; con su respuesta levanta el caso con la prioridad de su severidad y el responsable del área' do
    account.case_types.create!(name: 'Soporte', case_class: :support)
    triage('support', severidad: 2, intencion: 'no se genera la cotización')
    stub_model(tool_call('crear_caso', { titulo: 'No se genera la cotización', descripcion: 'Desde ayer' }),
               answer('¿Desde cuándo te pasa?'))
    reply_to(incoming('La cotización no se genera'))
    expect(CaseTicket.where(contact: contact).count).to eq(0) # primero una pregunta

    stub_model(tool_call('crear_caso', { titulo: 'No se genera la cotización', descripcion: 'Desde ayer' }),
               answer('Listo, tu folio es el que te di.'))
    reply_to(incoming('desde ayer'))
    ticket = CaseTicket.find_by(contact: contact)
    expect(ticket).to have_attributes(priority: 'high', assignee_id: support_user.id)
    expect(tracking.reload.motor2_state['case_folio']).to be_present
  end

  it 'Soporte: con el folio manda el instructivo de «al levantar un caso»' do
    account.case_types.create!(name: 'Soporte', case_class: :support)
    create(:ai_agent_attachment, tracking_template: agent, account: account, name: 'instructivo')
    agent.update!(resources: { 'files' => { 'instructivo' => { 'about' => 'Pasos para entrar', 'tickets' => ['*'] } } })
    triage('support', severidad: 1, intencion: 'no abre el sistema')
    stub_model(tool_call('crear_caso', { titulo: 'No abre', descripcion: 'No abre' }), answer('Tu folio es el que te di.'))
    reply_to(incoming('el sistema no abre, no puedo operar'))

    expect(conversation.messages.outgoing.where(private: false).last.attachments.count).to eq(1)
  end

  it 'Comercial: la cotización se registra como oportunidad con el vendedor; no se abre otra si ya tiene una' do
    account.case_types.create!(name: 'Oportunidad', case_class: :commercial)
    triage('sales', gestion: 'cotizacion', intencion: 'cotización de 10 usuarios')
    stub_model(tool_call('registrar_gestion', { tipo: 'cotizacion', detalle: '10 usuarios' }), answer('Listo, tu vendedor te da seguimiento.'))
    reply_to(incoming('Quiero cotización para 10 usuarios'))
    reply_to(incoming('y también para otra sucursal'))

    tickets = CaseTicket.where(contact: contact)
    expect(tickets.count).to eq(1)
    expect(tickets.first).to have_attributes(assignee_id: seller.id)
  end

  it 'no dice que ya levantó el caso si no llamó la herramienta (se reescribe)' do
    triage('support', intencion: 'falla')
    stub_model(answer('Ya levanté tu caso, tu folio es 123.'), answer('¿Desde cuándo te pasa?'))
    reply_to(incoming('No abre el sistema'))
    expect(conversation.messages.outgoing.last.content).to eq('¿Desde cuándo te pasa?')
  end

  it 'pide una persona sin decir para qué: le pregunta una vez y luego lo pasa al equipo del área' do
    triage('none', pide_persona: true)
    stub_model(answer('Con gusto, ¿qué necesitas para pasarte con quien corresponde?'))
    reply_to(incoming('Quiero hablar con una persona'))
    expect(tracking.reload.status).to eq('active')

    triage('admin', intencion: 'factura')
    stub_model(answer('Claro.'), tool_call('canalizar', { motivo: 'factura' }), answer('Te paso con administración.'))
    reply_to(incoming('es por mi factura'))
    expect(conversation.reload.assignee_id).to eq(billing_user.id)
  end

  describe 'una bandeja con los dos agentes' do
    let!(:prospects) do
      save_agent({ 'objective' => 'handoff', 'question_list' => ['¿Qué buscas?'] }, kind: 'prospects', name: 'Prospectos')
    end

    it 'se pueden prender los dos en la misma bandeja (no dos del mismo tipo)' do
      expect(prospects).to be_persisted
      other = account.tracking_templates.new(name: 'Otro', engine: '2', agent_function: 'customers', attending: true,
                                             attend_inbox_ids: [inbox.id], user: admin)
      expect(other).not_to be_valid
    end

    it 'quien ya es cliente va con el de clientes; los demás, con el de prospectos' do
      expect(Motor2::InboxRouter.agent_for(incoming('hola'))).to eq(prospects)
      account.case_types.create!(name: 'Soporte', case_class: :support)
      CaseTicket.create!(account: account, contact: contact, title: 'Ya era cliente', case_type: account.case_types.first)
      expect(Motor2::InboxRouter.agent_for(incoming('hola de nuevo'))).to eq(agent)
    end
  end
end
