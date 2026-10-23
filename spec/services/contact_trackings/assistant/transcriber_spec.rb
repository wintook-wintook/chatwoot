# frozen_string_literal: true

# proyecto@asistente_agentes_ia
require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::Transcriber do
  let(:account) { create(:account) }
  let(:audio_path) { Rails.root.join('tmp/dictado_spec.ogg') }

  before do
    File.binwrite(audio_path, 'OggS fake opus bytes')
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' })
  end

  after { FileUtils.rm_f(audio_path) }

  def archivo(type: 'audio/ogg')
    Rack::Test::UploadedFile.new(audio_path, type)
  end

  def openai_devuelve(texto, status: 200)
    stub_request(:post, described_class::API_URL)
      .to_return(status: status, body: { text: texto }.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  it 'devuelve el texto dictado' do
    openai_devuelve('  quiero un bot de citas  ')

    expect(described_class.new(account, file: archivo).call).to eq(text: 'quiero un bot de citas')
  end

  # Sin vocabulario "@ruta" sale "a ruta" y las etiquetas con cualquier ortografía.
  # Se mira el formulario armado: WebMock no ve el cuerpo de un multipart por stream.
  it 'arma el pedido con el modelo, el idioma y el vocabulario de la cuenta' do
    create(:label, account: account, title: 'citas')
    campos = described_class.new(account, file: archivo).send(:form).to_h { |nombre, valor| [nombre, valor] }

    expect(campos['model']).to eq(described_class::MODEL)
    expect(campos['language']).to eq(ContactTrackings::Assistant::Language.resolve.to_s)
    expect(campos['prompt']).to include('@ruta', '#citas')
    expect(campos['file']).to be_present
  end

  it 'avisa cada caso que no se puede transcribir' do
    expect(described_class.new(account, file: nil).call).to eq(error: :no_audio)
    expect(described_class.new(account, file: archivo(type: 'image/png')).call).to eq(error: :no_audio)

    grande = archivo
    allow(grande).to receive(:size).and_return(described_class::MAX_BYTES + 1)
    expect(described_class.new(account, file: grande).call).to eq(error: :too_large)

    account.hooks.destroy_all
    expect(described_class.new(account, file: archivo).call).to eq(error: :no_api_key)
  end

  it 'devuelve unavailable si OpenAI falla' do
    openai_devuelve('x', status: 500)

    expect(described_class.new(account, file: archivo).call).to eq(error: :unavailable)
  end
end
