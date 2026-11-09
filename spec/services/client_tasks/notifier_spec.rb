# frozen_string_literal: true

require 'rails_helper'

# Tareas con el cliente — avisarle con el enlace de su portal por su conversación.
RSpec.describe ClientTasks::Notifier do
  let(:account) { create(:account, locale: 'es') }
  let(:user) { create(:user, account: account, name: 'Luis') }
  let(:organization) { Organization.create!(account: account, name: 'Acme') }
  let(:contact) { create(:contact, account: account, name: 'Ana Pérez', organization_id: organization.id) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:type) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let(:ticket) do
    CaseTicket.create!(account: account, title: 'Falla', contact: contact, organization: organization, case_type: type,
                       conversation: conversation, assignee: user)
  end
  let(:task) { ticket.case_tasks.create!(account: account, title: 'Enviar constancia', audience: :client, due_at: 2.days.from_now) }

  it 'le escribe al cliente con el enlace del portal de su organización' do
    result = described_class.new(task, user).call(:assigned)
    expect(result).to eq(sent: true)
    message = conversation.messages.outgoing.last
    link = account.client_portal_links.active.find_by(organization: organization)
    expect(message.content).to include('Hola Ana', 'Enviar constancia', link.url)
    expect(message.sender).to eq(user)
  end

  it 'sin conversación no manda nada y dice por qué' do
    ticket.update_columns(conversation_id: nil) # rubocop:disable Rails/SkipsModelValidations
    conversation.destroy!
    expect(described_class.new(task.reload, user).call(:assigned)).to eq(sent: false, reason: 'no_conversation')
  end

  it 'con la ventana de 24 h cerrada no manda nada' do
    allow_any_instance_of(Conversation).to receive(:can_reply?).and_return(false) # rubocop:disable RSpec/AnyInstance
    expect(described_class.new(task, user).call(:assigned)).to eq(sent: false, reason: 'window_closed')
  end
end
