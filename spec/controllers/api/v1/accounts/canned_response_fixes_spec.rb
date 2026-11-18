# frozen_string_literal: true

require 'rails_helper'

# proyecto@arreglar_predefinidas — «Arreglar con IA» por la API.
RSpec.describe 'Canned Response Fixes API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:categoria) { CannedResponseCategory.create!(account: account, name: 'Productos') }
  let(:contenido) { "Producto X\n\nCuesta $1,500.\n\n#{'Detalle. ' * 200}" }
  let!(:original) do
    create(:canned_response, account: account, short_code: 'Producto X', content: contenido, category: categoria,
                             content_prompts: 'Sé breve', opcion: 3)
  end
  let(:partes) do
    [{ 'short_code' => 'Producto X — Precio', 'content' => 'Producto X cuesta $1,500.' },
     { 'short_code' => 'Producto X — Detalle', 'content' => "Producto X\n\n#{'Detalle. ' * 200}" }]
  end
  let(:fix) do
    account.canned_response_fixes.create!(canned_response: original, status: 'proposed', kind: 'oversize',
                                          source_ids: [original.id],
                                          source_digests: { original.id.to_s => CannedResponseFix.digest_for(original) },
                                          proposal: { 'action' => 'split', 'parts' => partes, 'questions' => [] })
  end
  let(:headers) { agent.create_new_auth_token }

  it 'sin OpenAI no propone' do
    post "/api/v1/accounts/#{account.id}/canned_responses/#{original.id}/fix", headers: headers

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'con OpenAI arma la propuesta en segundo plano y no lanza otra mientras corre' do
    create(:integrations_hook, :openai, account: account)
    url = "/api/v1/accounts/#{account.id}/canned_responses/#{original.id}/fix"

    expect { post url, headers: headers }.to have_enqueued_job(CannedResponses::FixJob)
    expect { post url, headers: headers }.not_to have_enqueued_job(CannedResponses::FixJob)
    get url, headers: headers
    expect(response.parsed_body['status']).to eq('running')
  end

  it 'aplica la división: crea las partes con lo heredado y elimina la original' do
    post "/api/v1/accounts/#{account.id}/canned_response_fixes/#{fix.id}/apply", params: { parts: partes }, headers: headers, as: :json

    expect(response).to have_http_status(:ok)
    nuevas = account.canned_responses.order(:id)
    expect(nuevas.pluck(:short_code)).to eq(['Producto X — Precio', 'Producto X — Detalle'])
    expect(nuevas.map { |r| [r.category_id, r.content_prompts, r.opcion] }.uniq).to eq([[categoria.id, 'Sé breve', 0]])
    expect(fix.reload.status).to eq('applied')
    expect(fix.result['deleted_ids']).to eq([original.id])
    expect(fix.snapshot.pluck('short_code')).to eq(['Producto X'])
  end

  it 'no aplica si falta un dato, salvo que se confirme que ya no aplica' do
    sin_precio = [partes.first.merge('content' => 'Producto X cuesta poco.'), partes.last]
    url = "/api/v1/accounts/#{account.id}/canned_response_fixes/#{fix.id}/apply"

    post url, params: { parts: sin_precio }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['checks']['data']['missing'].pluck('text')).to eq(['$1,500'])
    expect(account.canned_responses.count).to eq(1)

    post url, params: { parts: sin_precio, force: true }, headers: headers, as: :json
    expect(response).to have_http_status(:ok)
  end

  it 'no aplica una parte que pasa del tope, ni con force' do
    grande = [{ 'short_code' => 'Producto X', 'content' => "Producto X cuesta $1,500. #{'Detalle. ' * 260}" }]

    post "/api/v1/accounts/#{account.id}/canned_response_fixes/#{fix.id}/apply", params: { parts: grande, force: true },
                                                                                 headers: headers, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['checks']['blocking']).to include('size')
  end

  it 'si la original cambió, la propuesta ya no aplica' do
    fix
    original.update_columns(content: 'otra cosa') # rubocop:disable Rails/SkipsModelValidations

    post "/api/v1/accounts/#{account.id}/canned_response_fixes/#{fix.id}/apply", params: { parts: partes }, headers: headers, as: :json

    expect(response).to have_http_status(:conflict)
  end

  it 'condensar y limpiar conservan la misma predefinida (mismo id)' do
    fix.update!(proposal: fix.proposal.merge('action' => 'condense'))
    condensada = [{ 'short_code' => 'Producto X', 'content' => "Producto X cuesta $1,500. #{'Detalle. ' * 20}" }]

    post "/api/v1/accounts/#{account.id}/canned_response_fixes/#{fix.id}/apply", params: { parts: condensada },
                                                                                 headers: headers, as: :json

    expect(response).to have_http_status(:ok)
    expect(original.reload.content).to start_with('Producto X cuesta $1,500.')
  end

  it 'instrucciones en varias partes quedan todas marcadas como prompt' do
    fix.update!(proposal: fix.proposal.merge('action' => 'mark_prompt'))

    post "/api/v1/accounts/#{account.id}/canned_response_fixes/#{fix.id}/apply", params: { parts: partes }, headers: headers, as: :json

    expect(account.canned_responses.pluck(:content_is_prompt)).to eq([true, true])
  end

  it 'comprueba lo editado y descarta' do
    create(:integrations_hook, :openai, account: account)
    allow(CannedResponses::Fix::Embedder).to receive(:new).and_return(instance_double(CannedResponses::Fix::Embedder, call: nil))

    post "/api/v1/accounts/#{account.id}/canned_response_fixes/#{fix.id}/check", params: { parts: partes }, headers: headers, as: :json
    expect(response.parsed_body).to include('blocking' => [])

    post "/api/v1/accounts/#{account.id}/canned_response_fixes/#{fix.id}/discard", headers: headers
    expect(fix.reload.status).to eq('discarded')
    get "/api/v1/accounts/#{account.id}/canned_responses/#{original.id}/fix", headers: headers
    expect(response.parsed_body).to be_nil
  end
end
