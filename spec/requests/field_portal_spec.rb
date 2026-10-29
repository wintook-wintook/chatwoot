# frozen_string_literal: true

require 'rails_helper'

# Plan-Trabajo-Campo R5 — portal del cliente (/servicio/:token) y técnico externo (/tecnico/:token).
RSpec.describe 'Field portal' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:tech)    { create(:user, account: account, role: :agent, name: 'Ana Técnica') }
  let(:contact) { create(:contact, account: account, name: 'Jane Cliente') }
  let(:orden)   { CaseType.create!(account: account, name: 'Instalación', color: '#0d9488', case_class: :work_order) }
  let(:order)   { CaseTicket.create!(account: account, title: 'Instalar minisplit', contact: contact, case_type: orden, assignee: tech) }
  let(:token)   { order.ensure_report_token! }

  def visit_at(start)
    CaseMeeting.create!(account: account, case_ticket: order, title: 'Visita', starts_at: start, ends_at: start + 1.hour,
                        organizer: tech)
  end

  describe 'portal del cliente' do
    it 'muestra la visita y quién va; confirmar queda en el historial' do
      visit = visit_at(2.days.from_now.change(hour: 10))
      get "/servicio/#{token}"
      expect(response.body).to include('Ana Técnica', order.folio)

      post "/servicio/#{token}/visita", params: { response: 'confirmed' }
      expect(order.reload.visit_response_current).to include('status' => 'confirmed', 'meeting_id' => visit.id)
      expect(order.case_events.last.payload['field']).to eq('portal')
    end

    it 'pedir otra fecha; si la visita se mueve, la respuesta ya no vale' do
      visit = visit_at(2.days.from_now.change(hour: 10))
      post "/servicio/#{token}/visita", params: { response: 'reschedule', preferred: 'jueves en la tarde' }
      expect(order.reload.visit_response_current['preferred']).to eq('jueves en la tarde')

      visit.update!(starts_at: visit.starts_at + 1.day, ends_at: visit.ends_at + 1.day)
      expect(order.reload.visit_response_current).to eq({})
    end

    it 'califica solo ya terminada y una sola vez' do
      post "/servicio/#{token}/calificar", params: { rating: 5 }
      expect(order.reload.csat_rating).to be_nil

      order.update_columns(status: CaseTicket.statuses[:resolved], resolved_at: Time.current)
      post "/servicio/#{token}/calificar", params: { rating: 4, comment: 'Muy puntual' }
      post "/servicio/#{token}/calificar", params: { rating: 1 }
      expect(order.reload).to have_attributes(csat_rating: 4, csat_comment: 'Muy puntual')
      get "/reporte/#{token}"
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'técnico externo' do
    let(:base) { "/api/v1/accounts/#{account.id}/case_tickets/#{order.id}/service_report" }

    it 'recibe un enlace, llega, anota y termina; después el enlace ya no sirve' do
      post "#{base}/external_link", params: { name: 'Pedro Externo', phone: '5215550001111' },
                                    headers: admin.create_new_auth_token, as: :json
      external = response.parsed_body['service_report']['external']
      expect(external).to include('name' => 'Pedro Externo', 'active' => true)
      link = order.reload.external_token

      get "/tecnico/#{link}"
      expect(response.body).to include(order.folio)
      post "/tecnico/#{link}/llegue", params: { lat: 19.43, lng: -99.13 }
      entry = order.time_entries.visit.last
      expect(entry).to have_attributes(user_id: nil, note: 'Pedro Externo')
      post "/tecnico/#{link}/nota", params: { content: 'Se cambió el capacitor' }
      expect(order.work_logs.note.last.content).to eq('Se cambió el capacitor')

      post "/tecnico/#{link}/termine", params: { received_by: 'Jane' }
      expect(order.reload).to have_attributes(status: 'resolved', received_by: 'Jane', external_token: nil)
      expect(entry.reload.ended_at).to be_present
      get "/tecnico/#{link}"
      expect(response).to have_http_status(:gone)
    end

    it 'el enlace vence' do
      link = order.issue_external_link!(name: 'Pedro')
      order.update_columns(external_token_expires_at: 1.minute.ago)
      get "/tecnico/#{link}"
      expect(response).to have_http_status(:gone)
    end
  end

  describe 'sin señal (portal del técnico)' do
    let(:url) { "/api/v1/accounts/#{account.id}/field_visits/#{order.id}" }

    before do
      role = AccessRole.for_account(account).find { |r| r.key == 'technician' }
      account.account_users.find_by(user: tech).update!(access_role: role)
      order.update!(on_site: true)
    end

    it 'respeta la hora en que pasó si es de las últimas 24 horas' do
      at = 2.hours.ago.change(usec: 0)
      post "#{url}/arrive", params: { occurred_at: at.iso8601 }, headers: tech.create_new_auth_token, as: :json
      expect(order.time_entries.visit.last.started_at).to eq(at)
    end

    it 'ignora horas viejas o del futuro' do
      post "#{url}/arrive", params: { occurred_at: 3.days.ago.iso8601 }, headers: tech.create_new_auth_token, as: :json
      expect(order.time_entries.visit.last.started_at).to be_within(1.minute).of(Time.current)
    end
  end

  it 'el «Voy en camino» lleva el enlace del portal' do
    expect(I18n.t('field.on_my_way', name: 'J', technician: 'A', eta: '10:00', url: 'X')).to include('X')
  end
end
