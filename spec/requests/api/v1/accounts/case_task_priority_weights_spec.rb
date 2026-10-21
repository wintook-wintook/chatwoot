# frozen_string_literal: true

require 'rails_helper'

# Plan-Bandeja-Prioridad F3 — pesos del puntaje de «Mi día» por cuenta.
RSpec.describe 'Case Settings API — pesos de prioridad de tareas' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let(:url)     { "/api/v1/accounts/#{account.id}/case_setting" }
  let(:defaults) { Cases::TaskPriorityScore::DEFAULT_WEIGHTS }

  def patch_weights(weights, user: admin)
    patch url, params: { case_setting: { task_priority_weights: weights } }, headers: user.create_new_auth_token, as: :json
  end

  it 'muestra los vigentes y los de fábrica' do
    get url, headers: agent.create_new_auth_token, as: :json

    body = response.parsed_body
    expect(body['task_priority_weights']).to eq(defaults.stringify_keys)
    expect(body['task_priority_defaults']).to eq(defaults.stringify_keys)
  end

  it 'guarda solo lo que cambió y lo aplica al puntaje' do
    patch_weights(defaults.merge(sla_overdue: 50, project_overdue: 30, urgent_score: 90))

    expect(response).to have_http_status(:ok)
    expect(account.case_setting.reload.task_priority_weights).to eq('sla_overdue' => 50, 'urgent_score' => 90)
    expect(Cases::TaskPriorityScore.weights_for(account)).to include(sla_overdue: 50, project_overdue: 30, urgent_score: 90)
  end

  it 'restaurar = mandar los de fábrica (no queda nada guardado)' do
    patch_weights({ sla_overdue: 50 })
    patch_weights(defaults)

    expect(account.case_setting.reload.task_priority_weights).to eq({})
  end

  it 'rechaza valores fuera de rango o no numéricos; ignora llaves desconocidas' do
    patch_weights({ sla_overdue: 999 })
    expect(response).to have_http_status(:unprocessable_entity)

    patch_weights({ sla_overdue: 'mucho' })
    expect(response).to have_http_status(:unprocessable_entity)

    patch_weights({ inventado: 5, waiting: -30 })
    expect(response).to have_http_status(:ok)
    expect(account.case_setting.reload.task_priority_weights).to eq('waiting' => -30)
  end

  it 'solo un administrador los cambia' do
    patch_weights({ sla_overdue: 50 }, user: agent)
    expect(response).to have_http_status(:unauthorized)
  end
end
