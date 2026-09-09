# frozen_string_literal: true

# @knowledge_sources
require 'rails_helper'

RSpec.describe KnowledgeEmbeddable do
  let(:account) { create(:account) }
  let(:url) { 'https://api.openai.com/v1/embeddings' }
  let(:subject_class) { Class.new { include KnowledgeEmbeddable }.new }

  before do
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled',
                               settings: { 'api_key' => 'sk-test' })
  end

  # La API devuelve cada vector con su `index` y NO garantiza el orden del array.
  def openai_batch(vectors, shuffled: false)
    rows = vectors.each_with_index.map { |v, i| { 'index' => i, 'embedding' => v } }
    { 'data' => shuffled ? rows.reverse : rows }.to_json
  end

  def stub_embeddings(body, status: 200)
    stub_request(:post, url).to_return(status: status, body: body,
                                       headers: { 'Content-Type' => 'application/json' })
  end

  describe '#generate_embeddings' do
    it 'devuelve un vector por texto' do
      stub_embeddings(openai_batch([[0.1], [0.2], [0.3]]))

      expect(subject_class.generate_embeddings(account, %w[uno dos tres])).to eq([[0.1], [0.2], [0.3]])
    end

    # Si se confía en la posición del array, cada chunk queda con el embedding de
    # otro: la búsqueda devuelve resultados absurdos y NADA falla.
    it 'reordena por el index que devuelve la API, no por la posición' do
      stub_embeddings(openai_batch([[0.1], [0.2], [0.3]], shuffled: true))

      expect(subject_class.generate_embeddings(account, %w[uno dos tres])).to eq([[0.1], [0.2], [0.3]])
    end

    it 'manda un solo pedido para todo el lote' do
      stub_embeddings(openai_batch(Array.new(3) { [0.1] }))

      subject_class.generate_embeddings(account, %w[uno dos tres])

      expect(a_request(:post, url)).to have_been_made.once
    end

    # Es el punto del servicio: 367 ms por petición contra 8 ms por chunk en lote.
    it 'parte en lotes cuando hay más textos que el tamaño de lote' do
      stub_embeddings(openai_batch(Array.new(100) { [0.1] }))
      textos = Array.new(250) { |i| "texto #{i}" }

      subject_class.generate_embeddings(account, textos)

      expect(a_request(:post, url)).to have_been_made.times(3)
    end

    it 'nunca manda más textos por pedido que el tamaño de lote' do
      stub_embeddings(openai_batch(Array.new(100) { [0.1] }))

      subject_class.generate_embeddings(account, Array.new(250) { |i| "texto #{i}" })

      expect(a_request(:post, url).with { |req| JSON.parse(req.body)['input'].size <= 100 })
        .to have_been_made.times(3)
    end
  end

  describe 'cuando algo falla' do
    # Que un lote falle no debe tumbar la sincronización entera: los chunks sin
    # vector se saltean y el resto del sitio queda indexado.
    it 'devuelve nil en los textos del lote que falló, sin reventar' do
      stub_embeddings('boom', status: 500)

      expect(subject_class.generate_embeddings(account, %w[uno dos])).to eq([nil, nil])
    end

    it 'no pierde los lotes que sí anduvieron' do
      stub_request(:post, url)
        .to_return({ status: 500, body: 'boom' },
                   { status: 200, body: openai_batch(Array.new(100) { [0.9] }),
                     headers: { 'Content-Type' => 'application/json' } })

      resultado = subject_class.generate_embeddings(account, Array.new(200) { |i| "t#{i}" })

      expect(resultado.first(100)).to all(be_nil)
      expect(resultado.last(100)).to all(eq([0.9]))
    end

    it 'no sale a la red si la cuenta no tiene integración de OpenAI' do
      account.hooks.find_by(app_id: 'openai').update!(status: 'disabled')

      expect(subject_class.generate_embeddings(account, %w[uno])).to eq([])
      expect(a_request(:post, url)).not_to have_been_made
    end

    it 'no sale a la red sin textos' do
      expect(subject_class.generate_embeddings(account, [])).to eq([])
      expect(a_request(:post, url)).not_to have_been_made
    end

    it 'aguanta una respuesta sin data' do
      stub_embeddings({ 'data' => [] }.to_json)

      expect(subject_class.generate_embeddings(account, %w[uno])).to eq([nil])
    end
  end

  # No se toca el de a uno: lo usan canned_response y article, donde el volumen es
  # de a un registro. Cambiarlo sería arrastrar riesgo a un camino que funciona.
  describe '#generate_embedding, el de a uno' do
    it 'sigue mandando un texto suelto y devolviendo un vector' do
      stub_request(:post, url).to_return(
        status: 200, body: { 'data' => [{ 'embedding' => [0.5] }] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

      expect(subject_class.generate_embedding(account, 'uno')).to eq([0.5])
      expect(a_request(:post, url).with { |req| JSON.parse(req.body)['input'] == 'uno' }).to have_been_made
    end
  end
end
