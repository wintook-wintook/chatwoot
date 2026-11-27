# frozen_string_literal: true

require 'rails_helper'

# Motor 2.0 — el cliente escribe y contesta el agente 2.0. OpenAI no se llama: se simulan sus
# respuestas (Motor2::Runner#complete).
RSpec.describe Motor2::Reply do
  let(:account) { create(:account, name: 'Escuela Norte') }
  let(:seller) { create(:user, account: account, role: :agent, name: 'Ana López') }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Mario Pérez') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:motor2) { {} }
  let(:template) do
    create(:tracking_template, account: account, inbox_id: inbox.id, engine: '2', customer_display_name: 'Sofi',
                               objective: 'Inscribir al alumno en una carrera', motor2: motor2)
  end
  let!(:tracking) do
    create(:contact_tracking, account: account, contact: contact, inbox: inbox, conversation: conversation,
                              tracking_template: template, status: 'scheduled')
  end

  def tool_call(name, args)
    { 'role' => 'assistant', 'content' => nil,
      'tool_calls' => [{ 'id' => "call_#{name}", 'type' => 'function', 'function' => { 'name' => name, 'arguments' => args.to_json } }] }
  end

  def answer(text) = { 'role' => 'assistant', 'content' => text }

  def stub_model(*replies)
    allow_any_instance_of(Motor2::Runner).to receive(:complete).and_return(*replies) # rubocop:disable RSpec/AnyInstance
  end

  def incoming(text)
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming, content: text,
                     sender: contact)
  end

  def reply_to(message) = Motor2::ReplyJob.perform_now(message.id)

  def sent = conversation.messages.outgoing.where(private: false).order(:id)

  before do
    create(:user, account: account, role: :administrator, name: 'John') # el «usuario» con el que escribe el agente
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' })
  end

  it 'el mensaje del cliente lo toma el motor 2.0, no el 1.0' do
    expect { incoming('Hola, info') }.to have_enqueued_job(Motor2::ReplyJob)
    expect(ContactTrackingResponseAnalyzerJob).not_to have_been_enqueued
  end

  it 'un agente 1.0 sigue con su motor de siempre' do
    template.update!(engine: '1')
    expect { incoming('Hola') }.to have_enqueued_job(ContactTrackingResponseAnalyzerJob)
    expect(Motor2::ReplyJob).not_to have_been_enqueued
  end

  it 'contesta a nombre del agente y guarda la traza del turno' do
    stub_model(answer('¡Hola Mario! ¿Qué carrera te interesa?'))
    reply_to(incoming('Hola, quiero informes'))

    expect(sent.last.content).to eq('¡Hola Mario! ¿Qué carrera te interesa?')
    expect(sent.last.content_attributes).to include('ai_agent' => true, 'ai_agent_name' => 'Sofi',
                                                    'sentiment_auto_reply' => true, 'motor2_tracking_id' => tracking.id)
    expect(sent.last.content_attributes['motor2']).to include('tools' => [])
  end

  it 'si el cliente mandó otro mensaje después, contesta solo el último' do
    stub_model(answer('Respuesta'))
    first = incoming('Hola')
    incoming('¿tienen becas?')
    reply_to(first)
    expect(sent).to be_empty
  end

  context 'with datos del cliente' do
    let(:motor2) do
      { 'skills' => { 'data' => { 'on' => true, 'fields' => [{ 'key' => 'carrera', 'label' => 'Carrera', 'ask' => true,
                                                               'values' => %w[Derecho Psicología] }] } } }
    end

    it 'el código valida el valor y lo guarda en la memoria del seguimiento' do
      stub_model(tool_call('guardar_dato', { dato: 'carrera', valor: 'derecho' }), answer('¡Perfecto, Derecho!'))
      reply_to(incoming('Me interesa derecho'))
      expect(tracking.reload.motor2_state).to include('data' => { 'carrera' => 'Derecho' })
    end

    it 'un valor que no está permitido se rechaza y el modelo lo ve' do
      runner = Motor2::Runner.new(Motor2::Config.new(template), state: Motor2::State.new, history: [])
      runner.instance_variable_set(:@skills, Motor2::Skills.for(runner))
      result = runner.send(:tool, 'guardar_dato', { 'dato' => 'carrera', 'valor' => 'Medicina' })
      expect(result[:error]).to include('Derecho, Psicología')
    end
  end

  it 'bienvenida una sola vez; si además pregunta, también contesta' do
    template.update!(motor2: { 'welcome' => '¡Bienvenido a Escuela Norte!' })
    stub_model(answer('Sí, tenemos becas. ¿Qué carrera te interesa?'))
    reply_to(incoming('Hola, ¿tienen becas?'))
    expect(sent.pluck(:content)).to eq(['¡Bienvenido a Escuela Norte!', 'Sí, tenemos becas. ¿Qué carrera te interesa?'])
    expect(tracking.reload.motor2_state['welcome_sent']).to be(true)
  end

  it 'pasar a una persona: nota, asignación y el agente se pausa' do
    template.update!(motor2: { 'skills' => { 'handoff' => { 'user_id' => seller.id } } })
    stub_model(tool_call('pasar_a_humano', { motivo: 'Pide hablar con alguien' }), answer('Te paso con Ana.'))
    reply_to(incoming('Quiero hablar con una persona'))

    expect(conversation.reload.assignee_id).to eq(seller.id)
    expect(conversation.messages.where(private: true).last.content).to include('Pide hablar con alguien')
    expect(tracking.reload).to have_attributes(status: 'paused', outcome: 'handed_off')
  end

  it 'si una persona le escribió al cliente, el agente se hace a un lado' do
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, sender: seller,
                     content: 'Hola Mario, soy Ana')
    stub_model(answer('No debería salir'))
    reply_to(incoming('Gracias Ana'))
    expect(sent.pluck(:content)).to eq(['Hola Mario, soy Ana'])
    expect(tracking.reload.status).to eq('paused')
  end

  it 'pidió no ser contactado: baja y no contesta' do
    stub_model(answer('No debería salir'))
    reply_to(incoming('Ya no me escriban'))
    expect(sent).to be_empty
    expect(tracking.reload.status).to eq('cancelled')
  end
end
