# frozen_string_literal: true

require 'rails_helper'

# proyecto@crear_agente_conversando F4 — POST …/assistant/export
RSpec.describe 'Asistente de Agentes IA — exportar instrucciones' do
  let(:account) { create(:account) }
  let(:url) { "/api/v1/accounts/#{account.id}/contact_trackings/assistant/export" }

  it 'devuelve el .md a un administrador y a nadie más' do
    admin = create(:user, account: account, role: :administrator)
    post url, params: { name: 'Leo', draft: "[DATOS FIJOS]\nEMPRESA = K\n\n[ROL]\nTrabajas en %EMPRESA%",
                        fields: { objective: 'Vender' } }, headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body['filename']).to eq('instrucciones_leo.md')
    expect(response.parsed_body['content']).to include("## Objetivo\n\nVender", 'Trabajas en K')

    post url, params: { name: 'Leo' }, headers: create(:user, account: account, role: :agent).create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
  end
end
