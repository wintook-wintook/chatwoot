# frozen_string_literal: true

require 'rails_helper'

# Responsable fijo del contacto: sus conversaciones y sus casos nuevos van con
# él, por encima de turnos, automatizaciones y reglas; a mano sí se puede cambiar.
RSpec.describe Conversation, 'responsable fijo del contacto' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:owner)   { create(:user, account: account, role: :agent) }
  let(:other)   { create(:user, account: account, role: :agent) }
  let(:inbox)   { create(:inbox, account: account, enable_auto_assignment: true) }
  let(:contact) { create(:contact, account: account, owner: owner) }

  before do
    create(:inbox_member, user: owner, inbox: inbox)
    create(:inbox_member, user: other, inbox: inbox)
  end

  def new_conversation(attrs = {})
    create(:conversation, { account: account, inbox: inbox, contact: contact,
                            contact_inbox: create(:contact_inbox, contact: contact, inbox: inbox) }.merge(attrs))
  end

  describe 'conversaciones' do
    it 'nace con el responsable fijo aunque la bandeja reparta por turnos' do
      expect(new_conversation.reload.assignee).to eq(owner)
    end

    it 'deja una nota en la conversación' do
      expect { new_conversation }.to have_enqueued_job(Conversations::ActivityMessageJob)
        .with(anything, hash_including(content: I18n.t('conversations.activity.assignee.contact_owner', assignee_name: owner.name)))
    end

    it 'una regla automática no se la quita' do
      conversation = new_conversation
      conversation.update!(assignee: other)
      expect(conversation.reload.assignee).to eq(owner)
    end

    it 'a mano sí se cambia en esa conversación, y al reabrir vuelve al responsable fijo' do
      conversation = new_conversation
      conversation.manual_assignment = true
      conversation.update!(assignee: other)
      expect(conversation.reload.assignee).to eq(other)

      conversation.update!(status: :resolved)
      conversation.update!(status: :open)
      expect(conversation.reload.assignee).to eq(owner)
    end

    it 'en una bandeja donde no está el responsable siguen las reglas' do
      inbox.inbox_members.find_by(user: owner).destroy!
      expect(new_conversation(assignee: other).reload.assignee).to eq(other)
    end

    it 'sin responsable fijo no cambia nada' do
      contact.update!(owner: nil)
      expect(new_conversation(assignee: other).reload.assignee).to eq(other)
    end

    it 'el responsable tiene que ser de la cuenta' do
      contact.owner = create(:user)
      expect(contact).not_to be_valid
    end
  end

  describe 'casos' do
    let(:soporte) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }

    it 'un caso nuevo sin responsable elegido es del responsable fijo' do
      ticket = CaseTicket.create!(account: account, title: 'Falla', contact: contact, case_type: soporte)
      expect(ticket.assignee).to eq(owner)
    end

    it 'si se elige a alguien al crearlo, gana lo elegido' do
      ticket = CaseTicket.create!(account: account, title: 'Falla', contact: contact, case_type: soporte, assignee: other)
      expect(ticket.assignee).to eq(other)
    end

    it 'las reglas de casos no lo reasignan' do
      CaseRule.create!(account: account, name: 'A otro', conditions: [],
                       actions: [{ 'type' => 'assign_agent', 'value' => other.id.to_s }])
      ticket = CaseTicket.create!(account: account, title: 'Falla', contact: contact, case_type: soporte)
      Cases::RuleEngineService.new(ticket).evaluate!
      expect(ticket.reload.assignee).to eq(owner)
    end
  end

  it 'si el responsable sale de la cuenta, el contacto vuelve a las reglas' do
    contact
    Agents::DestroyJob.perform_now(account, owner)
    expect(contact.reload.owner_id).to be_nil
  end
end
