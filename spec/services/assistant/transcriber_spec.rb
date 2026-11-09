# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Assistant::Transcriber do
  let(:account) { create(:account, locale: 'es') }
  let(:upload) { Rack::Test::UploadedFile.new(StringIO.new('RIFF....'), 'audio/webm;codecs=opus', original_filename: 'x.webm') }

  before { account.hooks.create!(app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' }) }

  it 'manda el audio a OpenAI en español y regresa el texto' do
    form = nil
    allow_any_instance_of(Net::HTTP::Post).to receive(:set_form).and_wrap_original do |original, fields, *rest| # rubocop:disable RSpec/AnyInstance
      form = fields
      original.call(fields, *rest)
    end
    stub_request(:post, described_class::URL).to_return(status: 200, body: { text: ' Agéndame una llamada. ' }.to_json)

    expect(described_class.new(account: account).call(upload)).to eq('Agéndame una llamada.')
    expect(form.assoc('language')).to eq(%w[language es])
    expect(form.assoc('file')[2][:filename]).to eq('dictado.webm')
  end

  it 'si OpenAI falla regresa nil' do
    stub_request(:post, described_class::URL).to_return(status: 500, body: 'error')
    expect(described_class.new(account: account).call(upload)).to be_nil
  end

  it 'rechaza notas demasiado largas' do
    allow(upload).to receive(:size).and_return(11.megabytes)
    expect { described_class.new(account: account).call(upload) }.to raise_error(described_class::TooLarge)
  end
end
