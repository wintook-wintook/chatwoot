# frozen_string_literal: true

require 'rails_helper'

# Dali — «¿qué tengo pendiente?»: además de sus conversaciones sin responder, las menciones
# sin atender, el chat interno sin leer y (a quien reparte) las sin asignar esperando.
RSpec.describe Assistant::PendingTools do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :administrator, name: 'John') }
  let(:ana) { create(:user, account: account, role: :agent, name: 'Ana') }
  let(:grant) { Access::Grant.new(nil, nil) }
  let(:tools) { Assistant::Tools.new(account: account, user: user, grant: grant, zone: Time.zone) }
  let(:executor) { Assistant::Executor.new(account: account, user: user, grant: grant, zone: Time.zone) }
  let(:inbox) { create(:inbox, account: account, name: 'WhatsApp Ventas') }
  let(:contact) { create(:contact, account: account, name: 'Mario') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, assignee: ana) }

  def pending = tools.call('my_conversations', {})[:result]

  def mention_note
    note = create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, private: true,
                            sender: ana, content: "[@John](mention://user/#{user.id}/John) revisa el precio")
    Mention.create!(account: account, conversation: conversation, user: user, mentioned_at: note.created_at)
  end

  it 'menciones: quién y qué dijo; sale al escribir en la conversación' do
    mention_note
    expect(pending[:mentions].first).to include(id: conversation.display_id, by: 'Ana', note: '@John revisa el precio')

    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, private: true,
                     sender: user, content: 'Ya lo vi', created_at: 1.minute.from_now)
    expect(pending[:mentions]).to be_nil
  end

  it 'contesta al equipo con una nota interna (el cliente no la ve)' do
    mention_note
    proposal = tools.call('propose_internal_note', { 'conversation_id' => conversation.display_id, 'content' => 'Ya le mandé el precio' })[:proposal]
    executor.call('internal_note', proposal['payload'])
    expect(conversation.messages.where(private: true, sender: user).last.content).to eq('Ya le mandé el precio')
  end

  it 'chat interno: sin leer y de quién; al leerlo con Dali queda leído y se le contesta ahí' do
    InternalChannel::Setup.new(account).call
    direct = InternalChannel::Direct.new(account: account, user: ana).open!(user.id)
    direct.messages.create!(account: account, inbox: direct.inbox, sender: ana, message_type: :outgoing,
                            content: "¿Me ayudas, [@John](mention://user/#{user.id}/John)?")

    row = pending[:internal_chat].first
    expect(row).to include(room: 'Ana', unread: 1, mentions_you: true)
    expect(row[:last]).to include(from: 'Ana', text: '¿Me ayudas, @John?')

    tools.call('read_conversation', { 'conversation_id' => direct.display_id })
    expect(pending[:internal_chat]).to be_nil

    proposal = tools.call('propose_reply', { 'conversation_id' => direct.display_id, 'content' => 'Claro' })[:proposal]
    expect(executor.call('reply', proposal['payload'])['label']).to include('Ana')
  end

  it 'sin asignar esperando: solo a quien reparte, sin la bandeja Interno' do
    create(:conversation, account: account, inbox: inbox, contact: contact, assignee: nil).update_columns(waiting_since: 2.hours.ago) # rubocop:disable Rails/SkipsModelValidations
    InternalChannel::Setup.new(account).call
    expect(pending[:unassigned]).to include(total: 1, by_inbox: [{ inbox: 'WhatsApp Ventas', count: 1 }])

    allow(grant).to receive(:can?).and_call_original
    allow(grant).to receive(:can?).with(:reassign).and_return(false)
    expect(pending[:unassigned]).to be_nil
  end
end
