# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Contpaq::ServiceAgent do
  let(:account) { create(:account) }
  let(:source) do
    account.knowledge_sources.create!(
      name: 'Agente CONTPAQi', source_type: 'contpaq_support',
      config: { 'base_url' => 'https://apim.test/agente-servicio/v1',
                'token_url' => 'https://login.test/token', 'client_id' => 'cid',
                'client_secret' => 'secret', 'scope' => 'api://x/.default' }
    )
  end
  let(:agent) do
    described_class.new(source).tap { |a| allow(a).to receive(:sleep) } # no esperar el backoff
  end
  let(:answer_url) { 'https://apim.test/agente-servicio/v1/answer' }

  before do
    stub_request(:post, 'https://login.test/token')
      .to_return(status: 200, body: { access_token: 'jwt-abc', expires_in: 3599 }.to_json)
  end

  after { Redis::Alfred.delete(format(Redis::RedisKeys::CONTPAQ_ACCESS_TOKEN, source_id: source.id)) }

  def stub_answer(status: 200, body: nil)
    stub_request(:post, answer_url).to_return(status: status, body: (body || default_body).to_json)
  end

  def default_body
    { answer: 'Entra a Procesos > Timbrado.',
      sources: [{ title: 'Timbrado de nomina', source_url: 'https://contpaqi.test/timbrado' }],
      message_id: 'mid-1' }
  end

  describe '#ping' do
    it 'es true cuando el servicio esta Healthy, y va SIN token' do
      stub_request(:get, 'https://apim.test/agente-servicio/v1/ping')
        .to_return(status: 200, body: { status: 'Healthy' }.to_json)

      expect(agent.ping).to be(true)
      expect(WebMock).not_to have_requested(:post, 'https://login.test/token')
    end

    it 'es false si el gateway esta caido' do
      stub_request(:get, 'https://apim.test/agente-servicio/v1/ping').to_return(status: 503)
      expect(agent.ping).to be(false)
    end
  end

  describe '#answer' do
    it 'devuelve la respuesta ya redactada con sus fuentes' do
      stub_answer
      result = agent.answer(question: '¿Como timbro una nomina?', user_id: 'x@kontrolya.com')

      expect(result).to be_ok
      expect(result.answer).to eq('Entra a Procesos > Timbrado.')
      expect(result.sources).to eq([{ title: 'Timbrado de nomina', url: 'https://contpaqi.test/timbrado' }])
      expect(result.message_id).to eq('mid-1')
    end

    it 'manda el token en Authorization' do
      stub_answer
      agent.answer(question: 'x', user_id: 'x@kontrolya.com')
      expect(WebMock).to have_requested(:post, answer_url).with(headers: { 'Authorization' => 'Bearer jwt-abc' })
    end

    it 'sanea el conversation_id: es la causa mas frecuente de un 422 inesperado' do
      stub_answer
      agent.answer(question: 'x', user_id: 'x@kontrolya.com', conversation_id: 'acct 5/conv#12 ñ')

      expect(WebMock).to(have_requested(:post, answer_url)
        .with { |req| JSON.parse(req.body)['conversation_id'] == 'acct-5-conv-12--' })
    end

    it 'no manda conversation_id cuando no hay: su presencia es lo que activa la memoria' do
      stub_answer
      agent.answer(question: 'x', user_id: 'x@kontrolya.com')
      expect(WebMock).to(have_requested(:post, answer_url).with { |req| !JSON.parse(req.body).key?('conversation_id') })
    end

    it 'recorta la pregunta al maximo que admite el servicio' do
      stub_answer
      agent.answer(question: 'a' * 9000, user_id: 'x@kontrolya.com')
      expect(WebMock).to(have_requested(:post, answer_url)
        .with { |req| JSON.parse(req.body)['question'].length <= described_class::MAX_QUESTION })
    end

    it 'no consulta sin user_id: el servicio lo exige' do
      expect(agent.answer(question: 'x', user_id: nil).error).to eq(:invalid_request)
      expect(WebMock).not_to have_requested(:post, answer_url)
    end

    describe 'los tres 200 que no son respuesta' do
      it 'entrega el texto sin fuentes y no lo trata como error' do
        stub_answer(body: { answer: '¿De que producto CONTPAQi hablamos?', sources: [], message_id: 'mid-2' })
        result = agent.answer(question: 'no me deja entrar', user_id: 'x@kontrolya.com')

        expect(result).to be_ok
        expect(result.sources?).to be(false)
      end

      it 'descarta una fuente sin URL publica en vez de dar un enlace roto' do
        stub_answer(body: { answer: 'ok', sources: [{ title: 'Doc interno', source_url: '' }], message_id: 'm' })
        result = agent.answer(question: 'x', user_id: 'x@kontrolya.com')

        expect(result.sources).to eq([{ title: 'Doc interno', url: '' }])
      end
    end

    describe 'manejo de errores' do
      it 'renueva el token y reintenta UNA vez ante un 401' do
        stub_request(:post, answer_url)
          .to_return(status: 401, body: { message: 'Token JWT invalido' }.to_json)
          .then.to_return(status: 200, body: default_body.to_json)

        expect(agent.answer(question: 'x', user_id: 'x@kontrolya.com')).to be_ok
        expect(WebMock).to have_requested(:post, answer_url).twice
      end

      it 'no reintenta un 422: la peticion esta mal y va a fallar igual' do
        stub_request(:post, answer_url)
          .to_return(status: 422, body: { detail: [{ loc: %w[body question], msg: 'Field required' }] }.to_json)

        expect(agent.answer(question: 'x', user_id: 'x@kontrolya.com')).not_to be_ok
        expect(WebMock).to have_requested(:post, answer_url).once
      end

      it 'reintenta un 503 con espera progresiva' do
        stub_request(:post, answer_url)
          .to_return(status: 503).then.to_return(status: 200, body: default_body.to_json)

        expect(agent.answer(question: 'x', user_id: 'x@kontrolya.com')).to be_ok
      end

      it 'se rinde tras agotar los reintentos, sin romper la conversacion' do
        stub_request(:post, answer_url).to_return(status: 503)
        result = agent.answer(question: 'x', user_id: 'x@kontrolya.com')

        expect(result).not_to be_ok
        expect(result.error).to eq(:unavailable)
      end

      it 'no llama al servicio si la cuota del minuto esta agotada' do
        stub_answer
        allow(Contpaq::RateLimiter).to receive(:new)
          .and_return(instance_double(Contpaq::RateLimiter, allow?: false))

        expect(agent.answer(question: 'x', user_id: 'x@kontrolya.com').error).to eq(:unavailable)
        expect(WebMock).not_to have_requested(:post, answer_url)
      end
    end
  end
end
