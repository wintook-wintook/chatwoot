# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContactTrackings::OpenaiRequest do
  let(:url) { 'https://api.openai.com/v1/chat/completions' }
  let(:uri) { URI(url) }
  let(:http) { Net::HTTP.new(uri.host, uri.port).tap { |h| h.use_ssl = true } }
  let(:request) { Net::HTTP::Post.new(uri).tap { |r| r.body = '{}' } }
  let(:ok) { { status: 200, body: { choices: [{ message: { content: 'hola' } }] }.to_json } }

  before { stub_const("#{described_class}::RETRY_WAIT", 0) }

  it 'una respuesta buena no se repite' do
    stub_request(:post, url).to_return(ok)

    expect(described_class.perform(http, request, 'T').code).to eq('200')
    expect(a_request(:post, url)).to have_been_made.once
  end

  it 'un 429 o un cuerpo vacío se registran y se reintentan una vez' do
    stub_request(:post, url).to_return({ status: 429, body: '{"error":{"message":"Rate limit"}}' }, ok)
    allow(Rails.logger).to receive(:warn)

    expect(described_class.perform(http, request, 'T').code).to eq('200')
    expect(Rails.logger).to have_received(:warn).with(/OpenAI HTTP 429: .*Rate limit/)

    stub_request(:post, url).to_return({ status: 200, body: '' }, ok)
    expect(described_class.perform(http, request, 'T').body).to include('hola')
  end

  it 'un 400 no se reintenta' do
    stub_request(:post, url).to_return(status: 400, body: '{"error":{"message":"bad"}}')

    expect(described_class.perform(http, request, 'T').code).to eq('400')
    expect(a_request(:post, url)).to have_been_made.once
  end

  it 'si la red falla las dos veces devuelve nil' do
    stub_request(:post, url).to_timeout

    expect(described_class.perform(http, request, 'T')).to be_nil
    expect(a_request(:post, url)).to have_been_made.twice
  end
end
