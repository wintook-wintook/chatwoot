# frozen_string_literal: true

require 'rails_helper'

# Probador de agentes — el canal de pruebas: bandejas propias del probador (una por modelo), una
# plática con el agente asignado como lo asignan las automatizaciones, sin intentos a media prueba.
RSpec.describe AgentTester::Sandbox do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, name: 'Ana') }
  let(:sandbox) { described_class.new(account) }

  def model_hook(inbox) = account.hooks.find_by(app_id: 'tracking_bot', inbox_id: inbox.id)

  it 'crea su propia bandeja marcada y la reutiliza' do
    expect(sandbox.inbox).to have_attributes(name: 'Probador de agentes · gpt-4o-mini', channel_type: 'Channel::Api')
    expect(sandbox.inbox.channel.additional_attributes).to include('agent_tester' => true, 'model' => 'gpt-4o-mini')
    expect(described_class.new(account).inbox).to eq(sandbox.inbox)
  end

  it 'nunca toma una bandeja API de la cuenta, aunque no tenga webhook' do
    real = create(:inbox, account: account, channel: create(:channel_api, account: account, webhook_url: ''))
    expect(sandbox.inbox).not_to eq(real)
  end

  it 'una plática con el agente 1.0, en la bandeja de su modelo y con el seguimiento activo' do
    agent_inbox = create(:inbox, account: account)
    create(:integrations_hook, account: account, app_id: 'tracking_bot', inbox: agent_inbox, status: 'enabled',
                               settings: { 'model_ia' => 'gpt-4o' })
    template = create(:tracking_template, account: account, inbox_id: agent_inbox.id, complementary_prompt: 'Sé amable')
    conversation = sandbox.start(template, user: user)

    expect(conversation.inbox).to eq(sandbox.inbox('gpt-4o'))
    tracking = sandbox.tracking_for(conversation)
    expect(tracking).to have_attributes(tracking_template_id: template.id, status: 'active', complementary_prompt: 'Sé amable')
    expect(ContactTrackings::EngineConfig.model_for(conversation.inbox)).to eq('gpt-4o')
  end

  it 'dos agentes con modelos distintos no se pisan el modelo ni tocan el hook del agente' do
    big_inbox = create(:inbox, account: account)
    big_hook = create(:integrations_hook, account: account, app_id: 'tracking_bot', inbox: big_inbox, status: 'enabled',
                                          settings: { 'model_ia' => 'gpt-4o' })
    big = create(:tracking_template, account: account, inbox_id: big_inbox.id)
    small = create(:tracking_template, account: account, inbox_id: nil)

    first = sandbox.start(big, user: user)
    second = described_class.new(account).start(small, user: user)

    expect(ContactTrackings::EngineConfig.model_for(first.inbox)).to eq('gpt-4o')
    expect(ContactTrackings::EngineConfig.model_for(second.inbox)).to eq('gpt-4o-mini')
    expect(first.inbox).not_to eq(second.inbox)
    expect(big_hook.reload.updated_at).to eq(big_hook.updated_at)
  end

  it 'repone el modelo de su bandeja si alguien lo cambió' do
    box = sandbox.inbox('gpt-4o')
    model_hook(box).update!(settings: { 'model_ia' => 'gpt-3.5-turbo' })
    described_class.new(account).inbox('gpt-4o')
    expect(model_hook(box).reload.settings['model_ia']).to eq('gpt-4o')
  end

  it 'al terminar cierra el seguimiento y resuelve la plática sin disparar eventos' do
    template = create(:tracking_template, account: account)
    conversation = sandbox.start(template, user: user)
    expect(Rails.configuration.dispatcher).not_to receive(:dispatch).with(Events::Types::CONVERSATION_RESOLVED, anything, anything)

    sandbox.finish(conversation)
    expect(conversation.reload).to be_resolved
    expect(sandbox.tracking_for(conversation).status).to eq('completed')
  end

  it 'reconoce como suyas las pláticas marcadas, estén en la bandeja que estén' do
    old = create(:conversation, account: account, additional_attributes: { 'agent_tester' => true })
    create(:conversation, account: account)
    expect(sandbox.conversations).to contain_exactly(old)
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
    create(:message, account: account, inbox: conversation.inbox, conversation: conversation, message_type: :outgoing,
                     content: 'Hola, soy Sofi',
                     content_attributes: { traza: { 'ruta' => { 'nombre' => 'saludo' }, 'camino' => 'kbase' } })
    reply = sandbox.since(conversation, first.id).first
    expect(reply).to include(content: 'Hola, soy Sofi')
    expect(AgentTester::Trace.lines(reply[:trace])).to eq(['Ruta: saludo', 'Contestó: kbase'])
  end

  # proyecto@predefinidas_que_contestan
  describe 'búsqueda por plática y variables' do
    let(:prompt) { "[VARIABLES]\nCARRERA = VACÍO | texto\n" }
    let(:template) { create(:tracking_template, account: account, complementary_prompt: prompt) }

    it 'la plática fuerza la búsqueda sin tocar la cuenta' do
      conversation = sandbox.start(template, user: user, seleccion: 'on')
      expect(KnowledgeBase::Selection.enabled?(account, conversation)).to be(true)
      expect(KnowledgeBase::Selection.enabled?(account)).to be(false)
      expect(sandbox.start(template, user: user, seleccion: 'otra').additional_attributes).not_to have_key('agent_tester_seleccion')
    end

    it 'pone las variables de la prueba antes de que el cliente escriba, y las lee para guardarlas' do
      conversation = sandbox.start(template, user: user, variables: { 'CARRERA' => 'Licenciatura en Derecho' })
      expect(sandbox.variables_for(conversation)).to eq('CARRERA' => 'Licenciatura en Derecho')
    end
  end
end
