# frozen_string_literal: true

require 'rails_helper'

# Plan-Trabajo-Campo R3 — tablero de despacho: técnicos con sus visitas y choques,
# visitas sin técnico, órdenes sin visita, y asignar / agendar.
RSpec.describe 'Field dispatch API' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:tech)    { create(:user, account: account, role: :agent, name: 'Ana Técnica') }
  let(:contact) { create(:contact, account: account) }
  let(:orden)   { CaseType.create!(account: account, name: 'Instalación', color: '#0d9488', case_class: :work_order) }
  let(:url)     { "/api/v1/accounts/#{account.id}/field_dispatch" }
  let(:day)     { Time.zone.today }

  before do
    role = AccessRole.for_account(account).find { |r| r.key == 'technician' }
    account.account_users.find_by(user: tech).update!(access_role: role, field_profile: { 'skills' => ['A/C'], 'zone' => 'Norte' })
  end

  def order(attrs = {})
    CaseTicket.create!({ account: account, title: 'Instalar minisplit', contact: contact, case_type: orden }.merge(attrs))
  end

  def meeting(target, hour, minutes = 60)
    start = day.in_time_zone.change(hour: hour)
    CaseMeeting.create!(account: account, case_ticket: target, title: 'Visita', starts_at: start,
                        ends_at: start + minutes.minutes, organizer: target.assignee || admin)
  end

  it 'arma el día: técnicos con visitas y choques, sin técnico y sin visita' do
    first = order(assignee: tech)
    second = order(assignee: tech, title: 'Mantenimiento')
    meeting(first, 10, 90)
    clash = meeting(second, 11)
    loose = order
    meeting(loose, 12)
    pending = order(title: 'Sin visita')

    get url, params: { day: day.iso8601 }, headers: admin.create_new_auth_token, as: :json
    board = response.parsed_body
    ana = board['technicians'].find { |t| t['id'] == tech.id }
    expect(ana['skills']).to eq(['A/C'])
    expect(ana['zone']).to eq('Norte')
    expect(ana['visits'].size).to eq(2)
    expect(ana['conflicts']).to eq([clash.id])
    expect(board['unassigned'].pluck('id')).to eq([loose.id])
    expect(board['unscheduled'].pluck('id')).to include(pending.id)
  end

  it 'asignar a un técnico y agendar la visita (y la sincroniza con el calendario)' do
    pending = order
    expect do
      post "#{url}/assign", params: { order_id: pending.id, user_id: tech.id, starts_at: day.in_time_zone.change(hour: 16).iso8601 },
                            headers: admin.create_new_auth_token, as: :json
    end.to have_enqueued_job(Cases::MeetingSyncJob)
    expect(pending.reload.assignee).to eq(tech)
    visit = pending.case_meetings.last
    expect(visit.organizer).to eq(tech)
    expect(visit.ends_at - visit.starts_at).to eq(1.hour)
  end

  it 'mover una visita a otro técnico y de hora' do
    target = order(assignee: admin)
    visit = meeting(target, 9)
    post "#{url}/assign", params: { order_id: target.id, user_id: tech.id, meeting_id: visit.id,
                                    starts_at: day.in_time_zone.change(hour: 13).iso8601 },
                          headers: admin.create_new_auth_token, as: :json
    expect(target.reload.assignee).to eq(tech)
    expect(visit.reload.organizer).to eq(tech)
    expect(visit.starts_at.hour).to eq(13)
  end

  it 'el técnico no despacha' do
    get url, headers: tech.create_new_auth_token, as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it 'el perfil de campo se guarda desde Editar usuario' do
    patch "/api/v1/accounts/#{account.id}/agents/#{tech.id}",
          params: { agent: { field_profile: { skills: ['Refrigeración', ''], zone: 'Sur' } } },
          headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['field_profile']).to eq('skills' => ['Refrigeración'], 'zone' => 'Sur')
  end
end
