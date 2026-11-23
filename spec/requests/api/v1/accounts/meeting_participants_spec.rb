# frozen_string_literal: true

require 'rails_helper'

# Agenda: participantes de una tarea agendada (además del responsable). La ven en su Agenda, Mi día, Dali y Mi ruta;
# reciben avisos; solo el responsable la concluye y marca llegada.
RSpec.describe 'Meeting participants' do
  let(:account) { create(:account) }
  let(:organizer) { create(:user, account: account, role: :administrator, name: 'Ana Responsable') }
  let(:helper) { create(:user, account: account, role: :agent, name: 'Beto Ayudante') }
  let(:outsider) { create(:user, account: account, role: :agent, name: 'Ciro Otro') }
  let(:api) { "/api/v1/accounts/#{account.id}/agenda_items" }
  let(:starts) { 2.days.from_now.change(hour: 10) }

  def schedule(extra = {})
    post api, params: { title: 'Visita a Grúas', starts_at: starts.iso8601, ends_at: (starts + 1.hour).iso8601,
                        participant_ids: [helper.id, organizer.id] }.merge(extra), headers: organizer.create_new_auth_token, as: :json
    expect(response).to have_http_status(:created)
    CaseMeeting.find(response.parsed_body.dig('agenda_item', 'id'))
  end

  def notices(user) = user.notifications.where(notification_type: 'case_meeting_participant')

  before { allow(Cases::MeetingSyncJob).to receive(:perform_later) }

  it 'al agendar con participantes los guarda (sin el responsable) y les avisa' do
    meeting = schedule
    expect(meeting.participants.pluck(:user_id)).to eq([helper.id])
    expect(notices(helper).last.meta).to include('kind' => 'added', 'title' => 'Visita a Grúas')
    expect(I18n.with_locale(:es) { notices(helper).last.push_message_title }).to eq('Te agregaron a «Visita a Grúas»')
    expect(notices(organizer)).to be_empty
  end

  it 'el participante la ve en su Agenda («Participas») y quien no participa, no' do
    schedule
    get api, params: { start: starts.beginning_of_day.iso8601, end: starts.end_of_day.iso8601 }, headers: helper.create_new_auth_token
    item = response.parsed_body['agenda_items'].first
    expect(item).to include('title' => 'Visita a Grúas', 'participating' => true)
    expect(item['participants'].pluck('name')).to eq(['Beto Ayudante'])

    get api, params: { start: starts.beginning_of_day.iso8601, end: starts.end_of_day.iso8601 }, headers: outsider.create_new_auth_token
    expect(response.parsed_body['agenda_items']).to be_empty
    expect(CaseMeeting.for_user(helper.id).count).to eq(1)
  end

  it 'si cambia la hora o se cancela, les avisa' do
    meeting = schedule
    patch "#{api}/#{meeting.id}", params: { starts_at: (starts + 2.hours).iso8601, ends_at: (starts + 3.hours).iso8601 },
                                  headers: organizer.create_new_auth_token, as: :json
    expect(notices(helper).last.meta['kind']).to eq('rescheduled')

    Cases::Meetings::Participants.changed!(meeting.tap { |m| m.update!(status: :cancelled) }, { status: 'scheduled' })
    expect(notices(helper).last.meta['kind']).to eq('cancelled')
  end

  it '«No puedo ir»: solo un participante, y le llega al responsable' do
    meeting = schedule
    post "#{api}/#{meeting.id}/decline", params: { note: 'Tengo otra visita' }, headers: outsider.create_new_auth_token, as: :json
    expect(response).to have_http_status(:forbidden)

    post "#{api}/#{meeting.id}/decline", params: { note: 'Tengo otra visita' }, headers: helper.create_new_auth_token, as: :json
    expect(meeting.participants.first).to have_attributes(status: 'declined', note: 'Tengo otra visita')
    expect(I18n.with_locale(:es) { notices(organizer).last.push_message_title }).to eq('Beto Ayudante no puede ir a «Visita a Grúas»')
  end

  it 'en una visita el participante (Agenda «solo lo suyo») la ve, pero solo el responsable marca llegada' do
    meeting = schedule(is_visit: true)
    allow_any_instance_of(Access::Grant).to receive(:level).and_call_original # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(Access::Grant).to receive(:level).with(:agenda).and_return('own') # rubocop:disable RSpec/AnyInstance
    get "/api/v1/accounts/#{account.id}/agenda_visits/#{meeting.id}", headers: helper.create_new_auth_token
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('visit', 'participant_ids')).to eq([helper.id])

    post "/api/v1/accounts/#{account.id}/agenda_visits/#{meeting.id}/arrive", params: { lat: 25.6, lng: -100.3 },
                                                                              headers: helper.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized).or have_http_status(:forbidden)
    expect(meeting.reload.arrived_at).to be_nil
  end

  it '¿ocupado?: avisa si un participante ya tiene algo a esa hora' do
    schedule
    get "#{api}/busy", params: { user_ids: [helper.id, outsider.id], start: (starts + 30.minutes).iso8601, end: (starts + 90.minutes).iso8601 },
                       headers: organizer.create_new_auth_token
    expect(response.parsed_body['busy'].pluck('name')).to eq(['Beto Ayudante'])
  end

  it 'el recordatorio antes de empezar sale una vez' do
    meeting = schedule
    meeting.update_columns(starts_at: 10.minutes.from_now, ends_at: 70.minutes.from_now) # rubocop:disable Rails/SkipsModelValidations
    expect { 2.times { Cases::Meetings::Participants.remind_due! } }.to change { notices(helper).count }.by(1)
    expect(notices(helper).last.meta['kind']).to eq('reminder')
  end

  it 'si el participante tiene Google, va como invitado del evento' do
    meeting = schedule
    integration = UserCalendarIntegration.new(account: account, user: helper, google_email: 'beto@gmail.com')
    integration.save!(validate: false)
    expect(Cases::Meetings::GoogleMirrorService.new(meeting).attendees).to include('beto@gmail.com')
  end
end
