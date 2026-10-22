# frozen_string_literal: true

require 'rails_helper'

# @tickets_cases — POST /case_types/:id/change_class
RSpec.describe 'Case Types API — cambiar de clase' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let(:type)    { CaseType.create!(account: account, name: 'Implementación', color: '#06b6d4') }
  let(:url)     { "/api/v1/accounts/#{account.id}/case_types/#{type.id}/change_class" }

  before do
    account.enable_features!('case_project')
    CaseTicket.create!(account: account, title: 'Caso', contact: create(:contact, account: account), case_type: type)
  end

  it 'el administrador lo cambia: responde el tipo nuevo, el retirado y cuántos casos se quedan' do
    post url, params: { case_class: 'project' }, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body['case_type']).to include('case_class' => 'project', 'retired' => false, 'cases_count' => 0)
    expect(body['retired']).to include('name' => 'Implementación (anterior)', 'retired' => true, 'cases_count' => 1)
    expect(body['kept_cases']).to eq(1)
  end

  it 'un agente no puede' do
    post url, params: { case_class: 'project' }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'no cambia a una clase apagada en la cuenta' do
    post url, params: { case_class: 'work_order' }, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end
end
