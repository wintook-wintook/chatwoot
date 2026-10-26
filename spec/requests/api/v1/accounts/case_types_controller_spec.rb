# frozen_string_literal: true

require 'rails_helper'

# @tickets_cases — el flag `itil_enabled` de un tipo de caso viaja por la API
# (antes vivía en /case_setting, ahora es un atributo propio del tipo).
RSpec.describe 'Case Types API — itil_enabled por tipo' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }

  it 'crea un tipo con itil_enabled y lo devuelve en el JSON' do
    post "/api/v1/accounts/#{account.id}/case_types",
         params: { case_type: { name: 'Tickets', color: '#3b82f6', itil_enabled: true } },
         headers: admin.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body['case_type']['itil_enabled']).to be(true)
  end

  it 'default itil_enabled es false cuando no se manda' do
    post "/api/v1/accounts/#{account.id}/case_types",
         params: { case_type: { name: 'Soporte', color: '#3b82f6' } },
         headers: admin.create_new_auth_token,
         as: :json

    expect(response.parsed_body['case_type']['itil_enabled']).to be(false)
  end

  it 'permite alternar itil_enabled de un tipo ya existente vía update' do
    type = CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6', itil_enabled: false)

    patch "/api/v1/accounts/#{account.id}/case_types/#{type.id}",
          params: { case_type: { itil_enabled: true } },
          headers: admin.create_new_auth_token,
          as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['case_type']['itil_enabled']).to be(true)
    expect(type.reload.itil_enabled).to be(true)
  end

  it 'el listado de tipos incluye itil_enabled de cada uno' do
    CaseType.create!(account: account, name: 'Tickets', color: '#3b82f6', itil_enabled: true)
    CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6', itil_enabled: false)

    get "/api/v1/accounts/#{account.id}/case_types", headers: admin.create_new_auth_token, as: :json

    flags = response.parsed_body['case_types'].map { |t| [t['name'], t['itil_enabled']] }.to_h
    expect(flags).to eq('Tickets' => true, 'Soporte' => false)
  end
end
