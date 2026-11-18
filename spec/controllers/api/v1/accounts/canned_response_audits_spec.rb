# frozen_string_literal: true

require 'rails_helper'

# proyecto@auditoria_predefinidas — la pestaña «Auditoría».
RSpec.describe 'Canned Response Audit API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:url) { "/api/v1/accounts/#{account.id}/canned_response_audit" }
  let!(:larga) { create(:canned_response, account: account, short_code: 'LARGA', content: "#{'a' * 1500}\n\n#{'b' * 600}") }
  let!(:copia) { create(:canned_response, account: account, short_code: 'COPIA', content: 'igual') }
  let!(:finding) do
    account.canned_response_findings.create!(canned_response: larga, other_canned_response: copia, kind: 'duplicate',
                                             severity: 'high', similarity: 0.97, digest: 'x')
  end

  it 'enseña el resumen, las que pasan el tope con sus bloques y los hallazgos' do
    get url, headers: agent.create_new_auth_token

    body = response.parsed_body
    expect(body['summary']).to include('oversize' => 1, 'duplicate' => 1, 'contradiction' => 0)
    expect(body['oversize'].sole).to include('short_code' => 'LARGA', 'agent_chars' => 2109)
    expect(body['oversize'].sole['blocks'].pluck('chars')).to eq([1507, 600])
    expect(body['findings'].sole['responses'].pluck('short_code')).to eq(%w[LARGA COPIA])
  end

  it 'sin OpenAI no lanza la auditoría' do
    post url, headers: agent.create_new_auth_token

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error']).to eq('no_key')
  end

  it 'con OpenAI la lanza en segundo plano y no lanza otra mientras corre' do
    create(:integrations_hook, :openai, account: account)

    expect { post url, headers: agent.create_new_auth_token }.to have_enqueued_job(CannedResponses::AuditJob)
    expect { post url, headers: agent.create_new_auth_token }.not_to have_enqueued_job(CannedResponses::AuditJob)
    expect(account.canned_response_audits.count).to eq(1)
    expect(response.parsed_body['status']).to eq('running')
  end

  it 'descarta y reabre' do
    patch "#{url}/findings/#{finding.id}", params: { status: 'dismissed' }, headers: agent.create_new_auth_token, as: :json
    expect(finding.reload.status).to eq('dismissed')

    get url, params: { status: 'dismissed' }, headers: agent.create_new_auth_token
    expect(response.parsed_body['findings'].pluck('id')).to eq([finding.id])

    patch "#{url}/findings/#{finding.id}", params: { status: 'open' }, headers: agent.create_new_auth_token, as: :json
    expect(finding.reload.status).to eq('open')
  end

  it 'duplicadas: conserva una y elimina la otra (con sus hallazgos)' do
    post "#{url}/findings/#{finding.id}/keep", params: { keep_id: larga.id }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(account.canned_responses.pluck(:short_code)).to eq(%w[LARGA])
    expect(CannedResponseFinding.exists?(finding.id)).to be(false)
  end

  it 'no deja conservar una que no es del hallazgo' do
    post "#{url}/findings/#{finding.id}/keep", params: { keep_id: 0 }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(account.canned_responses.count).to eq(2)
  end

  it 'editar una predefinida quita sus hallazgos abiertos y la manda a revisar' do
    expect { larga.update!(content: 'corta') }.to have_enqueued_job(KnowledgeItemSyncJob).with(hash_including(audit: true))

    expect(CannedResponseFinding.exists?(finding.id)).to be(false)
  end

  it 'la tabla trae los caracteres, filtra por tamaño y cuenta los hallazgos' do
    get "/api/v1/accounts/#{account.id}/canned_responses", params: { page: 1, size: 'over' },
                                                           headers: agent.create_new_auth_token

    fila = response.parsed_body['payload'].sole
    expect(fila).to include('short_code' => 'LARGA', 'agent_chars' => 2109, 'open_findings' => 1)

    get "/api/v1/accounts/#{account.id}/canned_responses", params: { page: 1, sort: 'chars', order: 'asc' },
                                                           headers: agent.create_new_auth_token
    expect(response.parsed_body['payload'].pluck('short_code')).to eq(%w[COPIA LARGA])
  end
end
