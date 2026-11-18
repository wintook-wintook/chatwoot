# frozen_string_literal: true

require 'rails_helper'

# Probador de agentes — una plática de prueba no sale a ninguna parte: ni embudo, ni automatizaciones,
# ni webhooks, ni integraciones, ni reportes. Solo tiempo real.
RSpec.describe AgentTester::Events do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:template) { create(:tracking_template, account: account) }
  let(:conversation) { AgentTester::Sandbox.new(account).start(template, user: user) }
  let(:customer_conversation) { create(:conversation, account: account) }
  let(:now) { Time.zone.now }

  it 'reconoce la plática, sus mensajes y su contacto' do
    message = AgentTester::Sandbox.new(account).say(conversation, 'Hola')
    expect(described_class.tester?(conversation: conversation)).to be(true)
    expect(described_class.tester?(message: message)).to be(true)
    expect(described_class.tester?(contact: conversation.contact)).to be(true)
    expect(described_class.tester?(conversation: customer_conversation)).to be(false)
    expect(described_class.tester?(contact: customer_conversation.contact)).to be(false)
  end

  describe 'async dispatcher' do
    it 'no le pasa el evento a nadie (embudo, automatizaciones, webhooks, integraciones, reportes)' do
      [AutomationRuleListener, WebhookListener, KanbanFunnelListener, NotificationListener].each do |listener|
        expect(listener.instance).not_to receive(:conversation_created)
      end
      AsyncDispatcher.new.publish_event(Events::Types::CONVERSATION_CREATED, now, conversation: conversation)
    end

    it 'sus mensajes no van a integraciones (Slack…), webhooks, embudo ni reportes' do
      message = AgentTester::Sandbox.new(account).say(conversation, 'Hola')
      [HookListener, WebhookListener, KanbanFunnelListener, AutomationRuleListener].each do |listener|
        expect(listener.instance).not_to receive(:message_created)
      end
      AsyncDispatcher.new.publish_event(Events::Types::MESSAGE_CREATED, now, message: message)
    end

    it 'tampoco el alta del contacto «Probador · …» a los webhooks de la cuenta' do
      expect(WebhookListener.instance).not_to receive(:contact_created)
      AsyncDispatcher.new.publish_event(Events::Types::CONTACT_CREATED, now, contact: conversation.contact)
    end

    it 'las pláticas de clientes siguen igual' do
      expect(WebhookListener.instance).to receive(:conversation_created)
      dispatcher = AsyncDispatcher.new
      dispatcher.load_listeners
      dispatcher.publish_event(Events::Types::CONVERSATION_CREATED, now, conversation: customer_conversation)
    end
  end

  describe 'sync dispatcher' do
    it 'solo el tiempo real' do
      message = AgentTester::Sandbox.new(account).say(conversation, 'Hola')
      expect(ActionCableListener.instance).to receive(:message_created)
      expect(AgentBotListener.instance).not_to receive(:message_created)
      SyncDispatcher.new.dispatch(Events::Types::MESSAGE_CREATED, now, message: message)
    end
  end

  it 'el mensaje del cliente sí lo toma el motor' do
    template.update!(engine: '2')
    expect { AgentTester::Sandbox.new(account).say(conversation, 'Hola') }.to have_enqueued_job(Motor2::ReplyJob)
  end
end
