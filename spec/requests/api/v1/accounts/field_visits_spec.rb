# frozen_string_literal: true

require 'rails_helper'

# Plan-Trabajo-Campo R2 — portal del técnico: ruta del día, Voy en camino,
# Llegué / Terminé con ubicación y firma, y «Enviar al técnico».
RSpec.describe 'Field visits API' do
  let(:account)    { create(:account) }
  let(:admin)      { create(:user, account: account, role: :administrator) }
  let(:technician) { create(:user, account: account, role: :agent, name: 'Luis Técnico') }
  let(:contact)    { create(:contact, account: account, name: 'Jane Pérez', phone_number: '+5215512345678') }
  let(:inbox)      { create(:inbox, account: account) }
  let(:orden)      { CaseType.create!(account: account, name: 'Mantenimiento A/C', color: '#0d9488', case_class: :work_order) }
  let(:order) do
    CaseTicket.create!(account: account, title: 'Mantenimiento', contact: contact, case_type: orden, assignee: technician,
                       work_address: 'Av. Reforma 123')
  end
  let(:base) { "/api/v1/accounts/#{account.id}/field_visits" }

  before do
    technician_role = AccessRole.for_account(account).find { |r| r.key == 'technician' }
    account.account_users.find_by(user: technician).update!(access_role: technician_role)
    create(:conversation, account: account, inbox: inbox, contact: contact)
  end

  def visit_today(target = order, at = Time.zone.now.change(hour: 10))
    CaseMeeting.create!(account: account, case_ticket: target, title: 'Visita', starts_at: at, ends_at: at + 1.hour,
                        organizer: technician)
  end

  it 'la ruta de hoy trae sus visitas de órdenes en campo, en orden de hora' do
    visit_today(order, Time.zone.now.change(hour: 15))
    other = CaseTicket.create!(account: account, title: 'Instalación', contact: contact, case_type: orden, assignee: technician)
    visit_today(other, Time.zone.now.change(hour: 9))
    office = CaseTicket.create!(account: account, title: 'Remoto', contact: contact, case_type: orden, assignee: technician,
                                on_site: false)
    visit_today(office)

    get base, params: { day: Time.zone.today.iso8601 }, headers: technician.create_new_auth_token, as: :json
    titles = response.parsed_body['visits'].pluck('title')
    expect(titles).to eq(%w[Instalación Mantenimiento])
  end

  it 'Voy en camino avisa al cliente con la hora estimada' do
    post "#{base}/#{order.id}/on_my_way", params: { eta_minutes: 30 }, headers: technician.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['visit']['state']).to eq('on_the_way')
    expect(Message.where(conversation: contact.conversations).last.content).to include('Luis Técnico')
  end

  it 'Llegué y Terminé: horas, ubicación, conformidad con firma y la orden terminada' do
    travel_to(Time.zone.parse('2026-10-30 10:00')) do
      post "#{base}/#{order.id}/arrive", params: { lat: 19.43, lng: -99.13 }, headers: technician.create_new_auth_token, as: :json
      expect(response.parsed_body['visit']['state']).to eq('working')
      expect(order.reload.status).to eq('in_progress')
    end
    travel_to(Time.zone.parse('2026-10-30 11:15')) do
      post "#{base}/#{order.id}/finish",
           params: { lat: 19.43, lng: -99.13, received_by: 'Jane', conformity_note: 'Todo bien',
                     signature: 'data:image/png;base64,iVBORw0KGgo=' },
           headers: technician.create_new_auth_token, as: :json
    end
    expect(response).to have_http_status(:ok)
    order.reload
    expect(order.status).to eq('resolved')
    expect(order.received_by).to eq('Jane')
    expect(order.conformity_signature).to start_with('data:image/png')
    expect(order.actual_hours.to_f).to eq(1.25)
    entry = order.time_entries.visit.last
    expect(entry.location.keys).to match_array(%w[arrive leave])
    expect(order.report_sent_at).to be_present
  end

  it 'Terminé sin lo que pide el tipo regresa qué falta' do
    orden.update!(field_settings: { require_photos: true })
    post "#{base}/#{order.id}/finish", params: { received_by: 'Jane' }, headers: technician.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(order.reload.status).not_to eq('resolved')
  end

  it 'otro técnico no ve la orden' do
    other_tech = create(:user, account: account, role: :agent)
    role = AccessRole.for_account(account).find { |r| r.key == 'technician' }
    account.account_users.find_by(user: other_tech).update!(access_role: role)
    get "#{base}/#{order.id}", headers: other_tech.create_new_auth_token, as: :json
    expect(response).to have_http_status(:not_found)
  end

  it 'Enviar al técnico manda el enlace a su WhatsApp de agente' do
    tech_contact = create(:contact, account: account, name: 'Luis (agente)')
    account.account_users.find_by(user: technician).update!(agent_contact: tech_contact)
    conversation = create(:conversation, account: account, inbox: inbox, contact: tech_contact)
    post "#{base}/#{order.id}/send_to_technician", headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect(conversation.messages.last.content).to include("/campo/visita/#{order.id}")
  end

  # rubocop:disable Rails/SkipsModelValidations
  it '«Mis trabajos» trae sus órdenes terminadas en el periodo, con sus horas y la calificación' do
    done = CaseTicket.create!(account: account, title: 'Hecha', contact: contact, case_type: orden, assignee: technician)
    done.update_columns(status: CaseTicket.statuses['resolved'], received_at: 2.days.ago, csat_rating: 4)
    CaseTimeEntry.create!(account: account, case_ticket: done, user: technician, started_at: 2.days.ago,
                          ended_at: 2.days.ago + 90.minutes, minutes: 90, source: :visit)
    helper = CaseTicket.create!(account: account, title: 'Apoyo', contact: contact, case_type: orden, assignee: admin)
    helper.update_columns(status: CaseTicket.statuses['closed'], closed_at: 1.day.ago)
    CaseTimeEntry.create!(account: account, case_ticket: helper, user: technician, started_at: 1.day.ago,
                          ended_at: 1.day.ago + 30.minutes, minutes: 30, source: :manual)
    old = CaseTicket.create!(account: account, title: 'Vieja', contact: contact, case_type: orden, assignee: technician)
    old.update_columns(status: CaseTicket.statuses['resolved'], received_at: 40.days.ago)
    order # abierta: no sale

    get "#{base}/history", params: { from: 7.days.ago.to_date.iso8601, to: Time.zone.today.iso8601 },
                           headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['orders'].pluck('title')).to eq(['Apoyo']) # es el responsable, sin horas suyas

    get "#{base}/history", params: { from: 7.days.ago.to_date.iso8601, to: Time.zone.today.iso8601 },
                           headers: technician.create_new_auth_token, as: :json
    body = response.parsed_body
    # «Apoyo» no sale: el rol Técnico solo ve sus casos aunque haya registrado horas.
    expect(body['orders'].pluck('title')).to eq(['Hecha'])
    expect(body['orders'].pluck('minutes')).to eq([90])
    expect(body['totals']).to include('orders' => 1, 'minutes' => 90, 'csat_count' => 1, 'csat_average' => 4.0)
  end
  # rubocop:enable Rails/SkipsModelValidations
end
