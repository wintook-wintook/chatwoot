# frozen_string_literal: true

require 'rails_helper'

# proyecto@respuestas_predefinidas R2 — la tabla: paginación, orden y filtros.
RSpec.describe CannedResponseFinder do
  let(:account) { create(:account) }

  def predefinida(nombre, contenido: 'texto', estado: nil, vector: false, **extra)
    registro = create(:canned_response, account: account, short_code: nombre, content: contenido, **extra)
    registro.update_columns(embedding_status: estado) # rubocop:disable Rails/SkipsModelValidations
    if vector
      create(:knowledge_item, account: account, source_type: 'canned_response', source_id: registro.id,
                              embedding: Array.new(1536, 0.1))
    end
    registro
  end

  def nombres(params) = described_class.new(account, ActionController::Parameters.new(params)).perform[:records].map(&:short_code)

  before do
    predefinida('A_LISTA', vector: true)
    predefinida('B_SIN_VECTOR')
    predefinida('C_FALLO', estado: 'failed', contenido: 'horario de atención')
    predefinida('D_VIEJA', estado: 'failed', vector: true)
    predefinida('E_EN_CAMINO', estado: 'pending', content_prompts: 'mi prompt')
  end

  it 'filtra por estado igual que embedding_state (sin OpenAI, «no_key»)' do
    expect(nombres(state: 'ready')).to eq(%w[A_LISTA])
    expect(nombres(state: 'no_key')).to eq(%w[B_SIN_VECTOR])
    expect(nombres(state: 'missing')).to eq([])
    expect(nombres(state: 'failed')).to eq(%w[C_FALLO])
    expect(nombres(state: 'stale')).to eq(%w[D_VIEJA])
    expect(nombres(state: 'pending')).to eq(%w[E_EN_CAMINO])
    expect(nombres(state: 'not_ready')).to eq(%w[B_SIN_VECTOR C_FALLO])
  end

  it 'con OpenAI, las que no tienen vector son «missing»' do
    create(:integrations_hook, :openai, account: account)

    expect(nombres(state: 'missing')).to eq(%w[B_SIN_VECTOR])
    expect(nombres(state: 'no_key')).to eq([])
  end

  it 'busca en nombre y contenido, filtra por prompt propio' do
    expect(nombres(q: 'horario')).to eq(%w[C_FALLO])
    expect(nombres(q: 'vieja')).to eq(%w[D_VIEJA])
    expect(nombres(prompt: 'with')).to eq(%w[E_EN_CAMINO])
    expect(nombres(prompt: 'without').size).to eq(4)
  end

  it 'ordena y pagina, con el total' do
    resultado = described_class.new(account, ActionController::Parameters.new(sort: 'short_code', order: 'desc', page: 2,
                                                                              per_page: 2)).perform

    expect(resultado.slice(:count, :page, :per_page)).to eq(count: 5, page: 2, per_page: 2)
    expect(resultado[:summary]).to eq(no_key: 1, missing: 0, failed: 2)
    expect(resultado[:records].map(&:short_code)).to eq(%w[C_FALLO B_SIN_VECTOR])
  end
end
