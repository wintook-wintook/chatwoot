# frozen_string_literal: true

require 'rails_helper'

# Tareas con el cliente — recordatorio diario: vence mañana / venció ayer (una vez cada uno).
RSpec.describe ClientTasks::ReminderJob do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: create(:inbox, account: account), contact: contact) }
  let(:type) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let(:ticket) do
    CaseTicket.create!(account: account, title: 'Falla', contact: contact, case_type: type, conversation: conversation, assignee: owner)
  end

  def task(due_at, **attrs)
    ticket.case_tasks.create!({ account: account, title: "T #{due_at}", audience: :client, due_at: due_at }.merge(attrs))
  end

  it 'avisa por las que vencen mañana y las que vencieron ayer; no por las demás' do
    task(10.hours.from_now)
    task(30.hours.ago)
    task(5.days.ago)
    task(3.days.from_now)
    task(10.hours.from_now, audience: :internal)

    expect { described_class.perform_now }.to change { conversation.messages.outgoing.count }.by(2)
    expect(Notification.where(user: owner, notification_type: 'client_task_update').count).to eq(2)
  end
end
