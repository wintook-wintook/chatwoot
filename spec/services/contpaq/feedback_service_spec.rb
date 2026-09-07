# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Contpaq::FeedbackService do
  let(:account)      { create(:account) }
  let(:inbox)        { create(:inbox, account: account) }
  let(:contact)      { create(:contact, account: account, phone_number: '+523121122345') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:source) do
    account.knowledge_sources.create!(
      name: 'Agente CONTPAQi', source_type: 'contpaq_support',
      config: { 'base_url' => 'https://apim.test/v1', 'token_url' => 'https://login.test/token',
                'client_id' => 'cid', 'client_secret' => 's', 'scope' => 'api://x/.default' }
    )
  end
  let(:message) do
    create(:message, account: account, inbox: inbox, conversation: conversation,
                     message_type: :outgoing, content: 'Entra a Procesos > Timbrado.')
  end
  let(:feedback_url) { 'https://apim.test/v1/feedback/message' }

  before do
    stub_request(:post, 'https://login.test/token')
      .to_return(status: 200, body: { access_token: 'jwt', expires_in: 3599 }.to_json)
  end

  after { Redis::Alfred.delete(format(Redis::RedisKeys::CONTPAQ_ACCESS_TOKEN, source_id: source.id)) }

  def remember!
    described_class.remember(message, source: source, message_id: 'mid-1')
    message.reload
  end

  def stub_feedback(status: 200, action: 'recorded')
    stub_request(:post, feedback_url)
      .to_return(status: status, body: { status: 'ok', feedback_action: action }.to_json)
  end

  describe '.remember' do
    it 'guarda el identificador de la respuesta junto al mensaje enviado' do
      remember!
      expect(message.content_attributes['contpaq']).to include('message_id' => 'mid-1', 'source_id' => source.id)
    end

    it 'no pisa lo que el motor ya colgo del mensaje' do
      message.update!(content_attributes: { 'sentiment_auto_reply' => true })
      remember!
      expect(message.content_attributes['sentiment_auto_reply']).to be(true)
    end

    it 'un mensaje sin identificador no es calificable' do
      expect(described_class.ratable?(message)).to be(false)
    end
  end

  describe '#rate' do
    before { remember! }

    it 'envia la calificacion y la registra localmente' do
      stub_feedback
      expect(described_class.new(message).rate(1)).to be(true)

      expect(WebMock).to(have_requested(:post, feedback_url).with do |req|
        body = JSON.parse(req.body)
        body['message_id'] == 'mid-1' && body['rating'] == 1 && body['user_id'] == '3121122345@kontrolya.com'
      end)
      expect(message.reload.content_attributes['contpaq']).to include('rating' => 1)
    end

    it 'manda el comentario cuando lo hay: es lo mas util para diagnosticar' do
      stub_feedback
      described_class.new(message).rate(-1, comments: 'Contesto de otro producto')

      expect(WebMock).to(have_requested(:post, feedback_url)
        .with { |req| JSON.parse(req.body)['comments'] == 'Contesto de otro producto' })
    end

    it 'rechaza un rating que no sea 1 o -1 sin gastar la llamada' do
      expect(described_class.new(message).rate(0)).to be(false)
      expect(WebMock).not_to have_requested(:post, feedback_url)
    end

    it 'es false si el servicio responde algo distinto de recorded' do
      # Un fallo de escritura nunca se reporta como exito.
      stub_feedback(action: 'skipped')
      expect(described_class.new(message).rate(1)).to be(false)
      expect(message.reload.content_attributes['contpaq']).not_to have_key('rating')
    end

    it 'no reintenta un 404: el message_id no existe o es de otro integrador' do
      stub_request(:post, feedback_url).to_return(status: 404, body: '{}')
      expect(described_class.new(message).rate(1)).to be(false)
      expect(WebMock).to have_requested(:post, feedback_url).once
    end

    it 'reintenta un 503, que significa que NO se guardo' do
      stub_request(:post, feedback_url)
        .to_return(status: 503).then
        .to_return(status: 200, body: { feedback_action: 'recorded' }.to_json)
      agent = Contpaq::ServiceAgent.new(source)
      allow(agent).to receive(:sleep) # no esperar el backoff
      allow(Contpaq::ServiceAgent).to receive(:new).and_return(agent)

      expect(described_class.new(message).rate(1)).to be(true)
    end

    it 'es false si el mensaje no es una respuesta de CONTPAQi' do
      otro = create(:message, account: account, inbox: inbox, conversation: conversation)
      expect(described_class.new(otro).rate(1)).to be(false)
    end
  end
end
