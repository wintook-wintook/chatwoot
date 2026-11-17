# frozen_string_literal: true

require 'rails_helper'

# Probador de agentes — el canal de pruebas: una bandeja API sin webhook, una plática con el
# agente asignado como lo asignan las automatizaciones, sin intentos a media prueba.
RSpec.describe AgentTester::Sandbox do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, name: 'Ana') }
  let(:sandbox) { described_class.new(account) }

  it 'crea «Probador de agentes» si la cuenta no tiene un canal API sin webhook' do
    expect(sandbox.inbox).to have_attributes(name: 'Probador de agentes', channel_type: 'Channel::Api')
    expect(described_class.new(account).inbox).to eq(sandbox.inbox)
  end

  it 'una plática con el agente 1.0, con el modelo de la bandeja del agente y el seguimiento activo' do
    agent_inbox = create(:inbox, account: account)
    create(:integrations_hook, account: account, app_id: 'tracking_bot', inbox: agent_inbox, status: 'enabled',
                               settings: { 'model_ia' => 'gpt-4o' })
    template = create(:tracking_template, account: account, inbox_id: agent_inbox.id, complementary_prompt: 'Sé amable')
    conversation = sandbox.start(template, user: user)

    expect(conversation.inbox).to eq(sandbox.inbox)
    tracking = sandbox.tracking_for(conversation)
    expect(tracking).to have_attributes(tracking_template_id: template.id, status: 'active', complementary_prompt: 'Sé amable')
    expect(ContactTrackings::EngineConfig.model_for(sandbox.inbox)).to eq('gpt-4o')
  end

  it 'el mensaje del cliente lo toma el motor del agente (2.0 → Motor2::ReplyJob)' do
    template = create(:tracking_template, account: account, engine: '2')
    conversation = sandbox.start(template, user: user)
    expect { sandbox.say(conversation, 'Hola') }.to have_enqueued_job(Motor2::ReplyJob)
  end

  it 'lee las respuestas con su traza normalizada' do
    template = create(:tracking_template, account: account)
    conversation = sandbox.start(template, user: user)
    first = sandbox.say(conversation, 'Hola')
    create(:message, account: account, inbox: sandbox.inbox, conversation: conversation, message_type: :outgoing, content: 'Hola, soy Sofi',
                     content_attributes: { traza: { 'ruta' => { 'nombre' => 'saludo' }, 'camino' => 'kbase' } })
    reply = sandbox.since(conversation, first.id).first
    expect(reply).to include(content: 'Hola, soy Sofi')
    expect(AgentTester::Trace.lines(reply[:trace])).to eq(['Ruta: saludo', 'Contestó: kbase'])
  end
end
