# frozen_string_literal: true

require 'rails_helper'

RSpec.describe KnowledgeBase::DiscourseKeywordSearch do
  let(:config) { { 'url' => 'https://foro.example.com/', 'api_key' => 'k', 'username' => 'ADMIN' } }
  let(:respuesta) do
    { 'posts' => [{ 'id' => 7, 'topic_id' => 3, 'blurb' => 'El sitio es el centro operativo' }],
      'topics' => [{ 'id' => 3, 'title' => 'Desarrollo Web®', 'slug' => 'desarrollo-web' }] }
  end

  it 'arma los resultados igual que la búsqueda semántica' do
    expect(described_class.to_hits(respuesta, 'https://foro.example.com')).to eq(
      [{ post_id: 7, title: 'Desarrollo Web®', url: 'https://foro.example.com/t/desarrollo-web/3', blurb: 'El sitio es el centro operativo' }]
    )
  end

  it 'busca con las palabras cortas que saca la IA, no con la frase completa' do
    busqueda = described_class.new(config, ask: ->(_m) { "1. rediseño web\n- SEO restaurante\n" })
    stub_request(:get, %r{foro\.example\.com/search\.json}).to_return(body: respuesta.to_json, headers: { 'Content-Type' => 'application/json' })

    hits = busqueda.hits('Quiero rediseñar la página web de mi restaurante')

    expect(busqueda.terms('Quiero rediseñar la página web de mi restaurante')).to eq(['rediseño web', 'SEO restaurante'])
    expect(hits.pluck(:post_id)).to eq([7])
    expect(a_request(:get, 'https://foro.example.com/search.json?q=rediseño%20web')
             .with(headers: { 'Api-Username' => 'ADMIN' })).to have_been_made
  end

  it 'sin IA, busca con las primeras palabras con contenido' do
    busqueda = described_class.new(config, ask: ->(_m) {})

    expect(busqueda.terms('Hola, quiero rediseñar la página web de mi restaurante')).to eq(['rediseñar página'])
  end
end
