# frozen_string_literal: true

require 'rails_helper'

# Plan-Trabajo-Campo R4 — equipos del cliente y mantenimientos recurrentes.
RSpec.describe 'Customer assets and maintenance plans API' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:tech)    { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account, name: 'Jane') }
  let(:orden)   { CaseType.create!(account: account, name: 'Mantenimiento A/C', color: '#0d9488', case_class: :work_order) }
  let(:base)    { "/api/v1/accounts/#{account.id}" }

  def asset(attrs = {})
    account.customer_assets.create!({ contact: contact, name: 'Minisplit recámara', brand: 'LG', serial: 'X1',
                                      location: 'Av. Reforma 123' }.merge(attrs))
  end

  def plan(attrs = {})
    account.maintenance_plans.create!({ contact: contact, case_type: orden, title: 'Mantenimiento preventivo',
                                        every: 3, unit: :month, next_due_on: Date.current + 3.days,
                                        assignee: tech }.merge(attrs))
  end

  it 'equipos del cliente con su historial de órdenes' do
    equipo = asset
    CaseTicket.create!(account: account, title: 'Revisión', contact: contact, case_type: orden, customer_asset: equipo)
    get "#{base}/customer_assets", params: { contact_id: contact.id }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['customer_assets'].first['orders_count']).to eq(1)

    get "#{base}/customer_assets/#{equipo.id}", headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['customer_asset']['history'].pluck('title')).to eq(['Revisión'])
  end

  it 'alta de equipo y de mantenimiento desde el API' do
    post "#{base}/customer_assets", params: { customer_asset: { contact_id: contact.id, name: 'Clima oficina' } },
                                    headers: admin.create_new_auth_token, as: :json
    asset_id = response.parsed_body['customer_asset']['id']
    post "#{base}/maintenance_plans",
         params: { maintenance_plan: { contact_id: contact.id, customer_asset_id: asset_id, case_type_id: orden.id,
                                       title: 'Preventivo', every: 2, unit: 'month', next_due_on: Date.current + 30 } },
         headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:created)
    expect(response.parsed_body['maintenance_plan']['customer_asset']['name']).to eq('Clima oficina')
  end

  it 'solo tipos de orden de trabajo' do
    soporte = CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6')
    expect { plan(case_type: soporte) }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'el trabajo diario genera la orden dentro de la anticipación, avisa y adelanta la fecha' do
    inbox = create(:inbox, account: account)
    conversation = create(:conversation, account: account, inbox: inbox, contact: contact)
    equipo = asset
    current = plan(customer_asset: equipo)
    later = plan(next_due_on: Date.current + 40.days)

    MaintenancePlans::GenerateJob.perform_now

    order = current.case_tickets.first
    expect(order.title).to eq('Mantenimiento preventivo · Minisplit recámara')
    expect(order.customer_asset).to eq(equipo)
    expect(order.assignee).to eq(tech)
    expect(order.work_address).to eq('Av. Reforma 123')
    expect(current.reload.next_due_on).to eq(Date.current + 3.days + 3.months)
    expect(later.case_tickets).to be_empty
    expect(conversation.messages.last.content).to include(order.folio)
  end

  it 'no duplica si ya hay una orden abierta del plan' do
    current = plan
    MaintenancePlans::Generator.new(current).call
    MaintenancePlans::Generator.new(current.reload).call
    expect(current.case_tickets.count).to eq(1)
  end

  it 'generar ya desde la pantalla' do
    current = plan(next_due_on: Date.current + 60)
    post "#{base}/maintenance_plans/#{current.id}/generate", headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['case_ticket']['folio']).to be_present
  end

  it 'la orden se liga a un equipo del mismo cliente desde el reporte de servicio' do
    equipo = asset
    order = CaseTicket.create!(account: account, title: 'Visita', contact: contact, case_type: orden)
    patch "#{base}/case_tickets/#{order.id}/service_report", params: { customer_asset_id: equipo.id },
                                                             headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['service_report']['customer_asset']['name']).to eq('Minisplit recámara')
    expect(order.reload.customer_asset).to eq(equipo)
  end
end
