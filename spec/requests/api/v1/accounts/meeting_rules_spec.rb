# frozen_string_literal: true

require 'rails_helper'

# Tareas agendadas: solo la agendada se edita y se completa (realizada o no asistió, con su
# reporte); realizada o no asistió se reabre; cancelada no. Borrar: organizador en 24 h o admin.
RSpec.describe 'Meeting rules' do
  let(:account) { create(:account, locale: 'es') }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:type) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let(:ticket) { CaseTicket.create!(account: account, title: 'Falla', contact: create(:contact, account: account), case_type: type) }
  let(:url) { "/api/v1/accounts/#{account.id}/case_tickets/#{ticket.id}/meetings" }
  let(:starts) { 1.day.from_now }

  before { allow(Cases::MeetingSyncJob).to receive(:perform_later) }

  def meeting(**attrs)
    CaseMeeting.create!({ account: account, case_ticket: ticket, title: 'Visita', starts_at: starts, ends_at: starts + 1.hour,
                          organizer: admin }.merge(attrs))
  end

  def with_report(item)
    TaskReport.build_for(item, user: admin, content: 'Nadie en el domicilio', minutes: 20).tap(&:save!)
  end

  it 'completar con su reporte: no asistió; luego reabrir' do
    item = meeting
    with_report(item)
    patch "#{url}/#{item.id}/hold", params: { status: 'no_show' }, headers: admin.create_new_auth_token, as: :json
    expect(item.reload).to be_no_show

    patch "#{url}/#{item.id}/hold", params: { status: 'held' }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['error']).to include('cerrada')

    patch "#{url}/#{item.id}/hold", params: { status: 'scheduled' }, headers: admin.create_new_auth_token, as: :json
    expect(item.reload).to have_attributes(status: 'scheduled', held_at: nil)
  end

  it 'cerrada o cancelada no se edita; la cancelada no se reabre' do
    held = meeting(status: :held)
    patch "#{url}/#{held.id}", params: { case_meeting: { title: 'Otra' } }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)

    cancelled = meeting(status: :cancelled)
    patch "#{url}/#{cancelled.id}/hold", params: { status: 'scheduled' }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['error']).to include('Solo se reabre')
    expect(cancelled.reload).to be_cancelled
  end

  it 'deletable en el JSON: el organizador en 24 h o un admin' do
    create(:account_user, account: account, user: agent) unless agent.account_users.exists?(account: account)
    mine = meeting(organizer: agent)
    other = meeting(organizer: admin)

    get url, headers: agent.create_new_auth_token
    rows = response.parsed_body['case_meetings'].index_by { |m| m['id'] }
    expect(rows[mine.id]['deletable']).to be(true)
    expect(rows[other.id]['deletable']).to be(false)
  end

  it 'el calendario (agenda_items) tampoco cambia una cerrada' do
    held = meeting(status: :held)
    patch "/api/v1/accounts/#{account.id}/agenda_items/#{held.id}", params: { title: 'Otra' }, headers: admin.create_new_auth_token,
                                                                    as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
