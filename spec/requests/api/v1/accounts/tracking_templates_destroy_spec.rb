# frozen_string_literal: true

require 'rails_helper'

# feat/agentes_ia_unificado — un agente en uso no se borra: se dice en qué se usa.
RSpec.describe 'Borrar un Agente IA' do
  let(:account)  { create(:account) }
  let(:admin)    { create(:user, account: account, role: :administrator) }
  let(:template) { account.tracking_templates.create!(name: 'Cobranza', objective: 'Cobrar a tiempo') }
  let(:url)      { "/api/v1/accounts/#{account.id}/tracking_templates/#{template.id}" }

  def borrar
    delete url, headers: admin.create_new_auth_token, as: :json
  end

  it 'sin uso, se borra' do
    borrar

    expect(response).to have_http_status(:ok)
    expect(TrackingTemplate.exists?(template.id)).to be(false)
  end

  it 'con seguimientos activos no se borra y dice cuántos' do
    create(:contact_tracking, account: account, tracking_template: template, status: 'active')
    create(:contact_tracking, account: account, tracking_template: template, status: 'completed')

    borrar

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body).to include('error' => 'in_use')
    expect(response.parsed_body['usage']).to include('active_trackings' => 1)
    expect(TrackingTemplate.exists?(template.id)).to be(true)
  end

  it 'con una campaña (aunque esté terminada) no se borra' do
    create(:tracking_campaign, account: account, tracking_template: template, status: 'finished')

    borrar

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['usage']).to include('campaigns' => 1)
  end

  it 'con una automatización que lo asigna no se borra y la nombra' do
    create(:automation_rule, account: account, name: 'Cobrar al resolver',
                             actions: [{ 'action_name' => 'assign_tracking_template', 'action_params' => [template.id] }])

    borrar

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['usage']).to include('automations' => ['Cobrar al resolver'])
  end

  it 'solo seguimientos terminados no impiden borrarlo' do
    create(:contact_tracking, account: account, tracking_template: template, status: 'completed')

    borrar

    expect(response).to have_http_status(:ok)
  end
end
