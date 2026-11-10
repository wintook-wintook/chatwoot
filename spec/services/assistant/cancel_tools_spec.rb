# frozen_string_literal: true

require 'rails_helper'

# Dali — cancelar una tarea o tarea agendada con motivo.
RSpec.describe Assistant::CancelTools do
  let(:account) { create(:account, locale: 'es') }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:admin) { Access::Grant.new(nil, nil) }
  let(:tools) { Assistant::Tools.new(account: account, user: user, grant: admin, zone: Time.zone) }
  let(:executor) { Assistant::Executor.new(account: account, user: user, grant: admin, zone: Time.zone) }
  let(:contact) { create(:contact, account: account) }
  let(:type) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let(:ticket) { CaseTicket.create!(account: account, title: 'Falla', contact: contact, case_type: type) }

  before { Current.user = user }
  after { Current.user = nil }

  it 'propone cancelar con el motivo que encaja y al confirmar la cancela' do
    task = ticket.case_tasks.create!(account: account, title: 'Llamar a Mario')
    proposal = tools.call('propose_cancel_item', { 'kind' => 'task', 'id' => task.id, 'reason' => 'Duplicada' })[:proposal]
    expect(proposal['labels']['reasons'].pluck(:label)).to include('Duplicada')
    expect(account.task_outcomes.find(proposal['payload']['reason_id']).label).to eq('Duplicada')

    result = executor.call('cancel_item', proposal['payload'])
    expect(task.reload).to have_attributes(status: 'cancelled', cancel_reason: 'Duplicada')
    expect(result['label']).to include('Cancelada')
  end

  it 'una tarea agendada que ya se trabajó pide el tiempo' do
    meeting = CaseMeeting.create!(account: account, case_ticket: ticket, title: 'Visita', starts_at: 1.hour.from_now,
                                  ends_at: 2.hours.from_now, organizer: user, arrived_at: Time.current)
    proposal = tools.call('propose_cancel_item', { 'kind' => 'meeting', 'id' => meeting.id, 'reason' => 'Otro',
                                                   'comment' => 'El cliente no estaba' })[:proposal]
    expect(proposal['labels']['work_started']).to be(true)
    expect { executor.call('cancel_item', proposal['payload']) }.to raise_error(Assistant::Executor::Refused, /tiempo/)
    executor.call('cancel_item', proposal['payload'].merge('minutes' => 25, 'notify_client' => false))
    expect(meeting.reload).to be_cancelled
  end
end
