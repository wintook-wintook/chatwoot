require 'rails_helper'

# feat/chat_interno (plan v2, R3) — nada de lo de clientes toca «Interno».
RSpec.describe InternalChannel::Events do
  let(:account) { create(:account) }
  let!(:ana) { create(:user, account: account, role: :agent) }
  let!(:luis) { create(:user, account: account, role: :agent) }
  let!(:internal_inbox) { InternalChannel::Setup.new(account).call }
  let!(:direct) { InternalChannel::Direct.new(account: account, user: ana).open!(luis.id) }
  let!(:customer_conversation) { create(:conversation, account: account) }
  let(:message) { direct.messages.create!(account: account, inbox: internal_inbox, sender: ana, message_type: :outgoing, content: 'hola') }
  let(:now) { Time.zone.now }

  describe 'async dispatcher' do
    it 'only lets the notifications listener see internal events' do
      expect(AutomationRuleListener.instance).not_to receive(:conversation_created)
      expect(WebhookListener.instance).not_to receive(:conversation_created)
      expect(KanbanFunnelListener.instance).not_to receive(:conversation_created)
      expect(NotificationListener.instance).to receive(:conversation_created)
      AsyncDispatcher.new.publish_event(Events::Types::CONVERSATION_CREATED, now, conversation: direct)
    end

    it 'keeps every listener for customer conversations' do
      expect(AutomationRuleListener.instance).to receive(:conversation_created)
      expect(WebhookListener.instance).to receive(:conversation_created)
      dispatcher = AsyncDispatcher.new
      dispatcher.load_listeners
      dispatcher.publish_event(Events::Types::CONVERSATION_CREATED, now, conversation: customer_conversation)
    end
  end

  describe 'sync dispatcher' do
    it 'sends internal events to real time but not to bots', :aggregate_failures do
      message
      expect(ActionCableListener.instance).to receive(:message_created)
      expect(AgentBotListener.instance).not_to receive(:message_created)
      SyncDispatcher.new.dispatch(Events::Types::MESSAGE_CREATED, now, message: message)
    end
  end

  it 'does not notify the whole inbox about each internal conversation' do
    expect do
      NotificationListener.instance.conversation_created(Events::Base.new('conversation.created', now, conversation: direct))
    end.not_to change(Notification, :count)
  end

  it 'skips keyword actions and the seller webhook for internal messages', :aggregate_failures do
    message = direct.messages.new(account: account, inbox: internal_inbox, sender: ana, message_type: :outgoing, content: 'hola')
    expect(message).not_to receive(:check_keyword_actions_for_outgoing)
    expect(message).not_to receive(:dispatch_botseller_for_outgoing)
    message.save!
    expect(message.send(:internal_conversation?)).to be true
  end
end
