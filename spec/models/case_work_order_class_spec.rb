# frozen_string_literal: true

require 'rails_helper'

# @tickets_cases — Plan-Clase-Orden-de-Trabajo F1: la clase, su flujo de columnas
# y lo que hace (o no) según CaseType::CLASS_CAPABILITIES.
RSpec.describe 'Orden de trabajo — clase de caso', type: :request do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:contact) { create(:contact, account: account) }
  let(:orden)   { CaseType.create!(account: account, name: 'Visita técnica', color: '#0d9488', case_class: :work_order) }
  let(:soporte) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let(:url)     { "/api/v1/accounts/#{account.id}/case_types" }

  it 'solo se ofrece con el flag de la cuenta' do
    params = { case_type: { name: 'Instalación', color: '#0d9488', case_class: 'work_order' } }
    post url, params: params, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)

    account.enable_features!('case_work_order')
    post url, params: params, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:created)
    expect(response.parsed_body['case_type']['case_class']).to eq('work_order')
  end

  it 'nace con el flujo de la orden y nunca es pública' do
    orden.update!(public: true)
    expect(orden.reload.public).to be(false)
    expect(orden.case_type_columns.ordered.pluck(:label))
      .to eq(['Por programar', 'Programada', 'En ejecución', 'Pausada', 'Terminada', 'Cerrada', 'Cancelada'])
  end

  it 'no lleva SLA, no entra a Métricas de Soporte ni al portal, pero sí al bot' do
    wo = CaseTicket.create!(account: account, title: 'Instalar equipo', contact: contact, case_type: orden)
    ticket = CaseTicket.create!(account: account, title: 'Falla', contact: contact, case_type: soporte)

    expect(wo.resolution_time_target).to be_nil
    expect(account.case_tickets.with_capability(:sla)).to contain_exactly(ticket)
    expect(account.case_tickets.with_capability(:portal)).to contain_exactly(ticket)
    expect(account.case_tickets.with_capability(:bot_status)).to contain_exactly(ticket, wo)
  end

  it 'un caso sin tipo cuenta como Soporte' do
    untyped = CaseTicket.create!(account: account, title: 'Sin tipo', contact: contact)
    expect(account.case_tickets.with_capability(:sla)).to include(untyped)
    expect(untyped.class_capability?(:portal)).to be(true)
  end

  it 'tampoco se mueve a otra clase (clase fija)' do
    wo = CaseTicket.create!(account: account, title: 'Instalar equipo', contact: contact, case_type: orden)
    expect(wo.update(case_type_id: soporte.id)).to be(false)
  end
end
