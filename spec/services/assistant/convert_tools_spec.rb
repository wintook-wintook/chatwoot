# frozen_string_literal: true

require 'rails_helper'

# Dali — tarea ↔ tarea agendada: propone y, al confirmar, convierte con Cases::Conversion.
RSpec.describe Assistant::ConvertTools do
  let(:account) { create(:account, locale: 'es') }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:admin) { Access::Grant.new(nil, nil) }
  let(:tools) { Assistant::Tools.new(account: account, user: user, grant: admin, zone: Time.zone) }
  let(:executor) { Assistant::Executor.new(account: account, user: user, grant: admin, zone: Time.zone) }
  let(:contact) { create(:contact, account: account) }
  let(:type) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let(:ticket) { CaseTicket.create!(account: account, title: 'Falla', contact: contact, case_type: type) }

  before do
    Current.user = user
    allow(Cases::MeetingSyncJob).to receive(:perform_later)
  end

  after { Current.user = nil }

  it 'agenda la tarea con día y hora' do
    task = ticket.case_tasks.create!(account: account, title: 'Llamar a Mario', estimated_minutes: 30)
    proposal = tools.call('propose_convert_item', { 'kind' => 'task', 'id' => task.id,
                                                    'starts_at' => 2.days.from_now.strftime('%Y-%m-%dT10:00') })[:proposal]
    expect(proposal['labels']).to include('to_meeting' => true, 'keeps_task' => false)

    result = executor.call('convert_item', proposal['payload'])
    expect(result['label']).to include('agendada')
    expect(ticket.case_meetings.sole).to have_attributes(title: 'Llamar a Mario')
    expect(CaseTask.exists?(task.id)).to be(false)
  end

  it 'saca de la agenda la tarea agendada y la deja como tarea' do
    starts = 1.day.from_now
    meeting = CaseMeeting.create!(account: account, case_ticket: ticket, title: 'Visita', starts_at: starts,
                                  ends_at: starts + 1.hour, organizer: user)
    proposal = tools.call('propose_convert_item', { 'kind' => 'meeting', 'id' => meeting.id, 'notify' => false })[:proposal]

    result = executor.call('convert_item', proposal['payload'])
    expect(result['label']).to include('quedó como tarea')
    expect(ticket.case_tasks.sole.title).to eq('Visita')
  end
end
