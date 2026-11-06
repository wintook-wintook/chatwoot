# frozen_string_literal: true

require 'rails_helper'

# K1 — dos personas en el mismo caso: no se bloquea; se detecta el choque cuando cambian el
# MISMO dato (o el estado) y se ve quién más tiene abierto el caso.
RSpec.describe 'Case tickets: conflictos y presencia' do
  let(:account) { create(:account) }
  let(:ana)     { create(:user, account: account, role: :administrator, name: 'Ana') }
  let(:luis)    { create(:user, account: account, role: :administrator, name: 'Luis') }
  let(:contact) { create(:contact, account: account) }
  let(:soporte) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let(:ticket)  { CaseTicket.create!(account: account, title: 'Falla', contact: contact, case_type: soporte, priority: :medium) }
  let(:url)     { "/api/v1/accounts/#{account.id}/case_tickets/#{ticket.id}" }

  def edit(user, fields, expected, extra = {})
    patch url, params: { case_ticket: fields, expected: expected }.merge(extra), headers: user.create_new_auth_token, as: :json
  end

  it 'si otro ya cambió ese mismo dato, no se guarda: 409 con el valor actual y quién' do
    edit(ana, { priority: 'high' }, { priority: 'medium' })
    expect(response).to have_http_status(:ok)

    edit(luis, { priority: 'urgent' }, { priority: 'medium' }) # Luis aún veía «medium»

    expect(response).to have_http_status(:conflict)
    body = response.parsed_body
    expect(body['fields']).to eq([{ 'field' => 'priority', 'expected' => 'medium', 'current' => 'high' }])
    expect(body['last_change']['by']).to eq('Ana')
    expect(body['error']).to include('Ana')
    expect(ticket.reload.priority).to eq('high')
  end

  it '«Usar el mío» (force) guarda de todos modos' do
    edit(ana, { priority: 'high' }, { priority: 'medium' })
    edit(luis, { priority: 'urgent' }, { priority: 'medium' }, force: true)

    expect(response).to have_http_status(:ok)
    expect(ticket.reload.priority).to eq('urgent')
  end

  it 'datos distintos no chocan' do
    edit(ana, { priority: 'high' }, { priority: 'medium' })
    edit(luis, { title: 'Falla en planta' }, { title: 'Falla' })

    expect(response).to have_http_status(:ok)
    expect(ticket.reload).to have_attributes(priority: 'high', title: 'Falla en planta')
  end

  it 'el cambio de estado revisa desde qué estado se hizo' do
    ticket.update_columns(status: CaseTicket.statuses[:in_progress]) # rubocop:disable Rails/SkipsModelValidations

    patch "#{url}/transition", params: { status: 'resolved', expected_status: 'open' }, headers: luis.create_new_auth_token, as: :json

    expect(response).to have_http_status(:conflict)
    expect(response.parsed_body['fields'].first).to include('field' => 'status', 'current' => 'in_progress')
    expect(ticket.reload.status).to eq('in_progress')
  end

  it 'presencia: cada quien ve a los demás; al salir deja de aparecer' do
    get "#{url}/presence", headers: ana.create_new_auth_token, as: :json
    get "#{url}/presence", headers: luis.create_new_auth_token, as: :json
    expect(response.parsed_body['viewers']).to eq([{ 'id' => ana.id, 'name' => 'Ana' }])

    get "#{url}/presence", params: { leaving: true }, headers: ana.create_new_auth_token, as: :json
    get "#{url}/presence", headers: luis.create_new_auth_token, as: :json
    expect(response.parsed_body['viewers']).to eq([])
  end

  it 'quien solo puede ver el caso también avisa su presencia' do
    role = AccessRole.for_account(account).find { |r| r.key == 'technician' }
    role.update!(areas: role.areas.merge('service' => 'view'))
    agent = create(:user, account: account, role: :agent)
    account.account_users.find_by(user: agent).update!(access_role: role)

    get "#{url}/presence", headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
  end
end
