require 'rails_helper'

# feat/chat_interno (plan v2, R1) — la bandeja «Interno» como canal real.
RSpec.describe InternalChannel::Setup do
  let(:account) { create(:account) }
  let!(:ana) { create(:user, account: account, role: :administrator) }
  let!(:luis) { create(:user, account: account, role: :agent) }

  def internal_conversation(inbox, key)
    inbox.conversations.find_by("additional_attributes -> 'internal' ->> 'key' = ?", key)
  end

  it 'creates the inbox once, with every agent as member and no auto assignment', :aggregate_failures do
    inbox = described_class.new(account).call
    expect(described_class.new(account).call).to eq(inbox)
    expect(inbox.internal?).to be true
    expect(inbox.enable_auto_assignment).to be false
    expect(inbox.members).to contain_exactly(ana, luis)
    expect(Channel::Internal.where(account: account).count).to eq(1)
  end

  it 'creates the #general conversation with everyone and a hidden contact', :aggregate_failures do
    inbox = described_class.new(account).call
    general = internal_conversation(inbox, 'general')
    expect(general.internal?).to be true
    expect(general.conversation_participants.pluck(:user_id)).to contain_exactly(ana.id, luis.id)
    expect(general.contact.identifier).to eq('internal-chat')
    expect(inbox.conversations.count).to eq(1)
  end

  it 'does nothing when the account has the chat turned off' do
    off = create(:account, custom_attributes: { 'internal_chat_disabled' => true })
    create(:user, account: off, role: :agent)
    expect(described_class.new(off).call).to be_nil
    expect(Channel::Internal.where(account: off)).to be_empty
  end

  it 'adds a new agent to the inbox and to #general' do
    inbox = described_class.new(account).call
    marta = create(:user, account: account, role: :agent)
    expect(inbox.reload.members).to include(marta)
    expect(internal_conversation(inbox, 'general').conversation_participants.pluck(:user_id)).to include(marta.id)
  end

  describe 'teams' do
    it 'keeps one conversation per team with its members, following the team', :aggregate_failures do
      inbox = described_class.new(account).call
      team = create(:team, account: account, name: 'ventas')
      team.add_member(ana.id)

      conversation = internal_conversation(inbox, "team:#{team.id}")
      expect(conversation.conversation_participants.pluck(:user_id)).to eq([ana.id])

      team.add_member(luis.id)
      expect(conversation.reload.conversation_participants.pluck(:user_id)).to contain_exactly(ana.id, luis.id)

      team.remove_member(ana.id)
      expect(conversation.reload.conversation_participants.pluck(:user_id)).to eq([luis.id])

      team.destroy!
      expect(internal_conversation(inbox, "team:#{team.id}")).to be_nil
    end
  end

  describe InternalChannel::Direct do
    it 'opens one private conversation per pair', :aggregate_failures do
      first = described_class.new(account: account, user: ana).open!(luis.id)
      second = described_class.new(account: account, user: luis).open!(ana.id)
      expect(second).to eq(first)
      expect(first.conversation_participants.pluck(:user_id)).to contain_exactly(ana.id, luis.id)
      expect(first.additional_attributes['internal']['kind']).to eq('direct')
    end

    it 'refuses yourself and people outside the account' do
      direct = described_class.new(account: account, user: ana)
      expect { direct.open!(ana.id) }.to raise_error(InternalChannel::Direct::Error)
      expect { direct.open!(create(:user).id) }.to raise_error(InternalChannel::Direct::Error)
    end
  end
end
