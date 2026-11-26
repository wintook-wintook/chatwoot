# frozen_string_literal: true

require 'rails_helper'

# fix/calendario_eliminar F1 — «Eliminar evento» (eventos de Google sin tarea agendada).
RSpec.describe 'Google Calendar delete event API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent, name: 'Ana') }
  let(:google) { instance_double(GoogleCalendarService) }
  let(:url) { "/api/v1/accounts/#{account.id}/google_calendar/events" }
  let(:mine) { { 'id' => 'ev1', 'status' => 'confirmed', 'organizer' => { 'self' => true } } }

  before do
    integration = UserCalendarIntegration.create!(user: agent, account: account, google_email: 'ana@gmail.com',
                                                  tokens: { 'access_token' => 't' })
    allow(GoogleCalendarService).to receive(:new).with(integration).and_return(google)
    allow(google).to receive(:get_event).and_return(mine)
    allow(google).to receive(:delete_event).and_return(true)
    allow(google).to receive(:cancel_instance)
  end

  def delete_event(id = 'ev1', params = {})
    delete "#{url}/#{id}", params: params, headers: agent.create_new_auth_token, as: :json
  end

  it 'borra mi evento y avisa a los invitados' do
    delete_event

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to eq('deleted' => true, 'scope' => 'one')
    expect(google).to have_received(:delete_event).with('ev1', calendar_id: 'primary', send_updates: 'all')
  end

  it 'sin aviso si lo despalomeo, y en el calendario que diga' do
    delete_event('ev1', calendar_id: 'casa@group.calendar.google.com', notify: false)

    expect(google).to have_received(:get_event).with('ev1', calendar_id: 'casa@group.calendar.google.com')
    expect(google).to have_received(:delete_event)
      .with('ev1', calendar_id: 'casa@group.calendar.google.com', send_updates: 'none')
  end

  it 'si me invitaron solo lo quita de mi calendario y nunca avisa' do
    allow(google).to receive(:get_event).and_return(mine.merge('organizer' => { 'email' => 'otro@gmail.com' }))
    delete_event

    expect(google).to have_received(:delete_event).with('ev1', calendar_id: 'primary', send_updates: 'none')
  end

  describe 'serie' do
    before { allow(google).to receive(:get_event).and_return(mine.merge('id' => 'base_20261127', 'recurringEventId' => 'base')) }

    it '«Solo este» cancela la ocurrencia' do
      delete_event('base_20261127')

      expect(google).to have_received(:cancel_instance).with('base_20261127', calendar_id: 'primary', send_updates: 'all')
      expect(google).not_to have_received(:delete_event)
    end

    it '«Toda la serie» borra el maestro' do
      delete_event('base_20261127', scope: 'all')

      expect(response.parsed_body['scope']).to eq('all')
      expect(google).to have_received(:delete_event).with('base', calendar_id: 'primary', send_updates: 'all')
    end
  end

  it 'no borra el evento de una tarea agendada: hay que cancelarla' do
    CaseMeeting.create!(account: account, title: 'Visita', organizer: agent, google_event_id: 'ev1',
                        starts_at: 1.day.from_now, ends_at: 25.hours.from_now)
    delete_event

    expect(response).to have_http_status(:conflict)
    expect(response.parsed_body['reason']).to eq('linked_to_agenda_item')
    expect(google).not_to have_received(:delete_event)
  end

  it 'traduce el 403 de Google (calendario de solo lectura)' do
    allow(google).to receive(:delete_event)
      .and_raise('Google Calendar API error 403: {"error":{"message":"This calendar is read-only."}}')
    delete_event

    expect(response).to have_http_status(:forbidden)
    expect(response.parsed_body['error']).to eq(I18n.t('google_calendar_delete.no_permission'))
  end

  it 'si ya no estaba, cuenta como borrado' do
    allow(google).to receive(:get_event).and_return(:already_gone)
    delete_event

    expect(response.parsed_body).to eq('deleted' => true, 'scope' => 'one')
    expect(google).not_to have_received(:delete_event)
  end

  it 'si era la cita del bot, libera la cita del seguimiento y deja nota privada' do
    conversation = create(:conversation, account: account)
    tracking = create(:contact_tracking, account: account, contact: conversation.contact, inbox: conversation.inbox,
                                         conversation_id: conversation.id, appointment_event_id: 'ev1',
                                         appointment_at: 1.day.from_now, appointment_calendar_gid: 'primary')
    delete_event

    tracking.reload
    expect(tracking.appointment_event_id).to be_nil
    expect(tracking.appointment_at).to be_nil
    expect(tracking.ai_context).to include('[CITA ELIMINADA] Ana')
    note = conversation.messages.where(private: true).last
    expect(note.content).to eq(I18n.t('google_calendar_delete.bot_note', name: 'Ana'))
    expect(note.sender).to eq(agent)
  end

  it 'no toca citas del bot de otra cuenta' do
    other = create(:contact_tracking, appointment_event_id: 'ev1', appointment_at: 1.day.from_now)
    delete_event

    expect(other.reload.appointment_event_id).to eq('ev1')
  end
end
