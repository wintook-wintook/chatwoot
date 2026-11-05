# frozen_string_literal: true

require 'rails_helper'

# proyecto@respuestas_predefinidas R1 — el estado de vectorización y qué pasa cuando falla OpenAI.
RSpec.describe KnowledgeItemSyncJob do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:url) { 'https://api.openai.com/v1/embeddings' }
  let!(:canned) { create(:canned_response, account: account, short_code: 'PATITAS_CONSULTA', content: 'Cuesta $300') }

  def correr = described_class.perform_now(action: 'upsert', source_type: 'canned_response', source_id: canned.id, account_id: account.id)

  def con_openai = create(:integrations_hook, :openai, account: account)

  it 'sin integración de OpenAI deja la marca no_key' do
    correr

    expect(canned.reload.embedding_status).to eq('no_key')
    expect(KnowledgeItem.where(source_id: canned.id)).to be_empty
  end

  it 'con OpenAI guarda el vector y la deja lista' do
    con_openai
    stub_request(:post, url).to_return(status: 200, body: { data: [{ embedding: Array.new(1536, 0.1) }] }.to_json)

    correr

    expect(canned.reload).to have_attributes(embedding_status: 'ready', embedding_error: nil)
    expect(canned.embedded_at).to be_present
    expect(KnowledgeItem.find_by(source_type: 'canned_response', source_id: canned.id)).to have_attributes(
      title: 'PATITAS_CONSULTA', content: 'PATITAS_CONSULTA: Cuesta $300'
    )
  end

  it 'una clave inválida o la cuota agotada no se reintentan: queda el motivo' do
    con_openai
    stub_request(:post, url).to_return(status: 401, body: { error: { code: 'invalid_api_key' } }.to_json)
    correr
    expect(canned.reload).to have_attributes(embedding_status: 'failed', embedding_error: 'invalid_key')

    stub_request(:post, url).to_return(status: 429, body: { error: { code: 'insufficient_quota' } }.to_json)
    correr
    expect(canned.reload.embedding_error).to eq('quota')
  end

  it 'un error pasajero se vuelve a encolar y, al agotar los intentos, queda failed' do
    con_openai
    stub_request(:post, url).to_return(status: 503)

    expect { correr }.to have_enqueued_job(described_class)
    expect(canned.reload.embedding_status).to eq('pending')

    perform_enqueued_jobs do
      described_class.perform_later(action: 'upsert', source_type: 'canned_response', source_id: canned.id, account_id: account.id)
    end
    expect(canned.reload).to have_attributes(embedding_status: 'failed', embedding_error: 'http_503')
    expect(a_request(:post, url)).to have_been_made.times(described_class::ATTEMPTS + 1)
  end

  it 'sin red también se reintenta' do
    con_openai
    stub_request(:post, url).to_timeout

    expect { correr }.to have_enqueued_job(described_class)
  end

  # Antes: con la fuente desactivada se intentaba crear otra, chocaba con el índice único
  # y no se vectorizaba nada.
  it 'vectoriza aunque la fuente de predefinidas esté desactivada' do
    con_openai
    fuente = create(:knowledge_source, account: account, source_type: 'canned_response', status: 'inactive')
    stub_request(:post, url).to_return(status: 200, body: { data: [{ embedding: Array.new(1536, 0.1) }] }.to_json)

    correr

    expect(KnowledgeItem.find_by(source_id: canned.id).knowledge_source_id).to eq(fuente.id)
  end
end
