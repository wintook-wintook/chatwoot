# frozen_string_literal: true

require 'rails_helper'

# proyecto@crear_agente_conversando §15 — POST …/assistant/source_probe(/run)
RSpec.describe 'Asistente de Agentes IA — probar fuentes' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:url) { "/api/v1/accounts/#{account.id}/contact_trackings/assistant/source_probe" }

  it 'lista las directivas del borrador y solo para administradores' do
    post url, params: { draft: '@ruta(x: hola): @buscar_articulo' }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['directives'].pluck('directive')).to eq(['@buscar_articulo'])

    agente = create(:user, account: account, role: :agent)
    post url, params: { draft: 'x' }, headers: agente.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it 'sin frase contesta 422' do
    post "#{url}/run", params: { directive: '@buscar_articulo', phrase: '' }, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error']).to eq('no_phrase')
  end
end
