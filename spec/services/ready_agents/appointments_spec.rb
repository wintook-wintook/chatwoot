# frozen_string_literal: true

require 'rails_helper'

# Agentes listos — agendar la cita del prospecto. Google no se llama: se simulan los horarios
# (ContactTrackings::AvailabilitySlotService) y la sincronización (Cases::MeetingSyncJob).
RSpec.describe ReadyAgents::Appointments do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:seller) { create(:user, account: account, role: :agent, name: 'Ana López') }
  let!(:integration) { UserCalendarIntegration.create!(account: account, user: seller, google_email: 'ana@x.com', tokens: {}) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Mario Pérez', email: 'mario@x.com') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, assignee: nil) }
  let(:agent) do
    ReadyAgent.create!(account: account, kind: 'prospects', name: 'Sofi', enabled: true, inbox_ids: [inbox.id], created_by: admin,
                       settings: { 'objective' => 'appointment', 'appointment_user_ids' => [seller.id.to_s],
                                   'appointment_minutes' => '30', 'appointment_kind' => 'videollamada' })
  end
  let(:session) { ReadyAgentSession.create!(account: account, ready_agent: agent, conversation: conversation, contact: contact) }
  let(:start) { 2.days.from_now.change(hour: 10, min: 0, sec: 0) }
  let(:slot) do
    { slot: start, end_time: start + 30.minutes, agent_name: 'Ana López', calendar_integration_id: integration.id,
      google_calendar_id: 'primary' }
  end

  before do
    allow(Cases::MeetingSyncJob).to receive(:perform_later)
    allow_any_instance_of(ContactTrackings::AvailabilitySlotService).to receive(:call).and_return([slot]) # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(ContactTrackings::AvailabilitySlotService).to receive(:slot_for).and_return(slot) # rubocop:disable RSpec/AnyInstance
  end

  it 'ofrece horarios con el texto para el cliente' do
    result = described_class.new(agent, session: session).slots
    expect(result[:horarios].first).to include(inicio: start.strftime('%Y-%m-%dT%H:%M'), con: 'Ana López')
    expect(result[:horarios].first[:texto]).to match(/\A\w+ \d+ de \w+, 10:00\z/)
  end

  it 'agenda la cita en la Agenda con su contacto y a nombre de quien la atiende' do
    result = described_class.new(agent, session: session).book(start.strftime('%Y-%m-%dT%H:%M'), 'Quiere paneles')

    meeting = session.reload.case_meeting
    expect(result).to include(ok: true, con: 'Ana López')
    expect(meeting).to have_attributes(organizer_id: seller.id, contact_id: contact.id, starts_at: start, ends_at: start + 30.minutes)
    expect(meeting.title).to include('videollamada', 'Mario Pérez')
    expect(meeting.attendee_emails).to eq(['mario@x.com'])
    expect(Cases::MeetingSyncJob).to have_received(:perform_later).with(meeting.id, 'create')
  end

  it 'después del turno: etiqueta, nota, se la asigna a quien la atiende y el embudo pasa a «Cita»' do
    described_class.new(agent, session: session).book(start.strftime('%Y-%m-%dT%H:%M'), nil)
    expect { ReadyAgents::Outcomes.new(session, sender: admin).appointment_booked }
      .to have_enqueued_job(Kanban::FunnelTriggerJob).with(conversation.id, 'appointment_scheduled')

    expect(conversation.reload).to have_attributes(assignee_id: seller.id, label_list: include('interesado'))
    expect(conversation.messages.where(private: true).last.content).to include('Cita agendada', 'Ana López')
    expect(session.reload).to have_attributes(status: 'active')
  end

  it 'la mueve y la cancela (solo la que agendó)' do
    appointments = described_class.new(agent, session: session)
    expect(appointments.move('2026-12-01T10:00')).to include(error: include('No hay cita'))
    appointments.book(start.strftime('%Y-%m-%dT%H:%M'), nil)

    later = start + 1.day
    allow_any_instance_of(ContactTrackings::AvailabilitySlotService).to receive(:slot_for) # rubocop:disable RSpec/AnyInstance
      .and_return(slot.merge(slot: later, end_time: later + 30.minutes))
    described_class.new(agent, session: session.reload).move(later.strftime('%Y-%m-%dT%H:%M'))
    expect(session.case_meeting.reload.starts_at).to eq(later)

    described_class.new(agent, session: session.reload).cancel('Ya no puede')
    expect(session.case_meeting.reload).to have_attributes(status: 'cancelled', cancel_reason: 'Ya no puede')
  end

  it 'en el chat de prueba solo dice el horario, no crea nada' do
    result = nil
    expect { result = described_class.new(agent).book(start.strftime('%Y-%m-%dT%H:%M'), nil) }.not_to change(CaseMeeting, :count)
    expect(result).to include(ok: true, prueba: true)
  end

  it 'sin el objetivo de citas o sin calendarios no se ofrecen' do
    expect(described_class.available?(agent)).to be(true)
    agent.update!(settings: agent.settings.merge('objective' => 'handoff'))
    expect(described_class.available?(agent)).to be(false)
  end

  it 'si el horario se ocupó, de una vez ofrece otros' do
    other = start + 1.hour
    allow_any_instance_of(ContactTrackings::AvailabilitySlotService).to receive(:slot_for).and_return(nil) # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(ContactTrackings::AvailabilitySlotService) # rubocop:disable RSpec/AnyInstance
      .to receive(:call).and_return([slot, slot.merge(slot: other, end_time: other + 30.minutes)])

    result = described_class.new(agent, session: session).book(start.strftime('%Y-%m-%dT%H:%M'), nil)
    expect(result[:error]).to include('ocupar')
    expect(result[:horarios].pluck(:inicio)).to eq([other.strftime('%Y-%m-%dT%H:%M')])
    expect(session.reload.case_meeting).to be_nil
  end

  it 'si no puede leer el calendario, no dice «ocupado»: lo pasa a una persona y dice de quién reconectar' do
    allow_any_instance_of(ContactTrackings::AvailabilitySlotService).to receive(:slot_for).and_return(nil) # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(ContactTrackings::AvailabilitySlotService).to receive(:call).and_return([]) # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(ContactTrackings::AvailabilitySlotService).to receive_messages( # rubocop:disable RSpec/AnyInstance
      calendars_unreadable?: true, unreadable_users: ['Ana López']
    )

    result = described_class.new(agent, session: session).book(start.strftime('%Y-%m-%dT%H:%M'), nil)
    expect(result).to include(sin_agenda: true)
    expect(result[:motivo]).to include('Ana López', 'reconéctalo')
    expect(described_class.new(agent, session: session).slots).to include(sin_agenda: true)
  end
end
