# frozen_string_literal: true

require 'rails_helper'

# proyecto@crear_agente_conversando §15 P3 — fuentes en vivo, como el motor.
RSpec.describe ContactTrackings::Assistant::SourceProbeLive do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:user) { create(:user, account: account) }
  let(:probe) { described_class.new(account, inbox: inbox, user: user) }
  let(:config) { { 'url' => 'https://foro.test', 'api_key' => 'k', 'username' => 'system' } }
  let(:semantic) { %r{https://foro.test/discourse-ai/embeddings/semantic-search.json} }

  def respuesta_foro(*titulos)
    { posts: titulos.each_with_index.map { |_, i| { id: i + 1, topic_id: i + 10, blurb: "extracto #{i}" } },
      topics: titulos.each_with_index.map { |t, i| { id: i + 10, title: t, slug: "tema-#{i}" } } }.to_json
  end

  describe 'foro' do
    before { create(:knowledge_source, account: account, source_type: 'discourse', name: 'Foro Kontrolya', config: config) }

    it 'busca como el motor y marca los 3 que tomaría' do
      stub_request(:get, semantic).to_return(status: 200, body: respuesta_foro('A', 'B', 'C', 'D'))

      resultado = probe.forum('foro kontrolya', 'no puedo timbrar')

      expect(resultado).to include(kind: 'live', service: 'forum', status: 'ok', mode: 'semantic', max_results: 3)
      expect(resultado[:results].map { |r| [r[:title], r[:used]] }).to eq([['A', true], ['B', true], ['C', true], ['D', false]])
      expect(resultado[:results].first[:url]).to eq('https://foro.test/t/tema-0/10')
    end

    it 'sin Discourse AI cae a la búsqueda normal con los términos que saca la IA' do
      create(:integrations_hook, :openai, account: account)
      stub_request(:get, semantic).to_return(status: 404)
      stub_request(:post, 'https://api.openai.com/v1/chat/completions')
        .to_return(status: 200, body: { choices: [{ message: { content: "timbrar factura\n" } }] }.to_json)
      stub_request(:get, %r{https://foro.test/search.json}).to_return(status: 200, body: respuesta_foro('Timbrado'))

      resultado = probe.forum('Foro Kontrolya', 'no puedo timbrar mi factura')

      expect(resultado).to include(mode: 'keyword', terms: ['timbrar factura'], status: 'ok')
      expect(resultado[:results].pluck(:title)).to eq(['Timbrado'])
    end

    it 'una fuente que no existe lo dice' do
      expect(probe.forum('Otro foro', 'x')).to eq(kind: 'live', error: 'source_missing')
    end
  end

  describe '@discourse' do
    it 'usa la integración de la bandeja del agente' do
      create(:integrations_hook, account: account, app_id: 'discourse', inbox: inbox, status: 'enabled', settings: config)
      stub_request(:get, semantic).to_return(status: 200, body: respuesta_foro)

      expect(probe.discourse_integration('hola')).to include(service: 'forum', status: 'no_results')
    end

    it 'sin bandeja o sin integración lo dice' do
      expect(described_class.new(account).discourse_integration('x')).to eq(kind: 'live', error: 'needs_inbox')
      expect(probe.discourse_integration('x')).to eq(kind: 'live', error: 'hook_missing')
    end
  end

  describe 'CONTPAQi' do
    let!(:fuente) { create(:knowledge_source, account: account, source_type: 'contpaq_support', name: 'Soporte') }
    let(:agente) { instance_double(Contpaq::ServiceAgent) }

    before { allow(Contpaq::ServiceAgent).to receive(:new).with(fuente).and_return(agente) }

    it 'abre un hilo nuevo a nombre de quien prueba y muestra la respuesta con sus fuentes' do
      respuesta = Contpaq::ServiceAgent::Result.new(answer: 'Ve a Configuración…', sources: [{ title: 'Manual', url: 'https://m' }])
      allow(agente).to receive(:answer).and_return(respuesta)

      expect(probe.contpaq('soporte', '¿cómo timbro?')).to eq(
        kind: 'live', service: 'contpaq', status: 'ok', answer: 'Ve a Configuración…', sources: [{ title: 'Manual', url: 'https://m' }]
      )
      expect(agente).to have_received(:answer).with(
        question: '¿cómo timbro?', user_id: "asistente-prueba-#{user.id}@kontrolya.com", conversation_id: a_string_starting_with('asistente-')
      )
    end

    it 'sin respuesta dice por qué' do
      allow(agente).to receive(:answer).and_return(Contpaq::ServiceAgent::Result.new(error: :unavailable))

      expect(probe.contpaq('Soporte', 'x')).to include(status: 'no_answer', reason: 'unavailable')
    end
  end
end
