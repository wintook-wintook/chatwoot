# frozen_string_literal: true

require 'rails_helper'

# Motor 2.0 › «Qué sabe» con un foro (Discourse): se consulta en vivo, como en el 1.0. Antes se buscaba en
# lo guardado en la plataforma y salía vacío.
RSpec.describe Motor2::ForumSearch do
  let(:account) { create(:account) }
  let(:source) do
    account.knowledge_sources.create!(source_type: 'discourse', name: 'Foro', status: 'active',
                                      config: { 'url' => 'https://foro.test', 'api_key' => 'k', 'username' => 'bot' })
  end
  let(:hits) do
    [{ post_id: 1, title: 'Cambiar contraseña', url: 'https://foro.test/t/1', blurb: 'resumen 1' },
     { post_id: 2, title: 'Olvidé mi contraseña', url: 'https://foro.test/t/2', blurb: 'resumen 2' }]
  end

  before do
    stub_const('Motor2::ForumSearch::PAUSE', 0)
    stub_request(:get, 'https://foro.test/posts/1.json').to_return(body: { raw: 'Ve a Preferencias › Cuenta.' }.to_json)
    stub_request(:get, 'https://foro.test/posts/2.json').to_return(status: 404)
  end

  it 'con Discourse AI: los temas con el texto de cada publicación (o su resumen si no se puede leer)' do
    allow(KnowledgeBase::DiscourseSemanticSearch).to receive(:hits).and_return(hits)
    found = described_class.new(source, ask: ->(_m) { '' }).call('¿cómo cambio mi contraseña?')

    expect(found).to eq([{ titulo: 'Cambiar contraseña', informacion: 'Ve a Preferencias › Cuenta.', liga: 'https://foro.test/t/1' },
                         { titulo: 'Olvidé mi contraseña', informacion: 'resumen 2', liga: 'https://foro.test/t/2' }])
    expect(a_request(:get, 'https://foro.test/posts/1.json').with(headers: { 'Api-Key' => 'k', 'Api-Username' => 'bot' })).to have_been_made
  end

  it 'sin Discourse AI: la búsqueda normal con las búsquedas cortas de la IA' do
    allow(KnowledgeBase::DiscourseSemanticSearch).to receive(:hits).and_return(KnowledgeBase::DiscourseSemanticSearch::NOT_AVAILABLE)
    keyword = instance_double(KnowledgeBase::DiscourseKeywordSearch, hits: hits.first(1))
    allow(KnowledgeBase::DiscourseKeywordSearch).to receive(:new).and_return(keyword)

    expect(described_class.new(source, ask: ->(_m) { 'contraseña' }).call('¿cómo cambio mi contraseña?').size).to eq(1)
  end

  it 'Motor2::Search lo usa para las fuentes de foro' do
    allow(KnowledgeBase::DiscourseSemanticSearch).to receive(:hits).and_return(hits.first(1))
    found = Motor2::Search.new(account, ["discourse:#{source.id}"]).call('contraseña', only: 'Foro')
    expect(found.find { |f| f[:fuente] == 'Foro' }[:resultados].first[:titulo]).to eq('Cambiar contraseña')
  end
end
