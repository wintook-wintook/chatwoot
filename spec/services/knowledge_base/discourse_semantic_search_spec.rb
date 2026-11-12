# frozen_string_literal: true

require 'rails_helper'

# La búsqueda semántica del foro, sacada de KnowledgeBaseResponseService#discourse_hits.
RSpec.describe KnowledgeBase::DiscourseSemanticSearch do
  let(:config) { { 'url' => 'https://foro.test/', 'api_key' => 'k' } }
  let(:url) { %r{https://foro.test/discourse-ai/embeddings/semantic-search.json\?q=timbrar} }

  it 'regresa los hits con su liga, y manda la llave del foro' do
    stub_request(:get, url).with(headers: { 'Api-Key' => 'k', 'Api-Username' => 'system' }).to_return(
      status: 200, body: { posts: [{ id: 1, topic_id: 9, blurb: 'b' }], topics: [{ id: 9, title: 'Timbrar', slug: 'timbrar' }] }.to_json
    )

    expect(described_class.hits('timbrar', config)).to eq([{ post_id: 1, title: 'Timbrar', url: 'https://foro.test/t/timbrar/9', blurb: 'b' }])
  end

  it 'sin Discourse AI (404) avisa; con error, nada' do
    stub_request(:get, url).to_return(status: 404)
    expect(described_class.hits('timbrar', config)).to eq(:not_available)

    stub_request(:get, url).to_raise(SocketError)
    expect(described_class.hits('timbrar', config)).to eq([])
  end
end
