# frozen_string_literal: true

require 'rails_helper'

# El agente 2.0 lee lo que dicen las notas de voz y lo que muestran las imágenes del cliente
# (Motor2::MessageText / Motor2::MediaReader). OpenAI no se llama: se simula.
RSpec.describe Motor2::MessageText do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }

  def message_with(file_type, type: :incoming, content: '')
    message = create(:message, account: account, inbox: inbox, conversation: conversation, message_type: type, content: content)
    message.attachments.create!(account: account, file_type: file_type,
                                file: fixture_file_upload(Rails.root.join('spec/assets/sample.png'), 'image/png'))
    message
  end

  before do
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' })
    Rails.cache.clear
  end

  it 'una imagen del cliente llega como lo que muestra (con su texto tal cual)' do
    allow_any_instance_of(Motor2::MediaReader).to receive(:chat).and_return('Pantalla con el error «Error 424».') # rubocop:disable RSpec/AnyInstance
    expect(described_class.call(message_with(:image, content: 'me sale esto'))).to eq("me sale esto\n\n[imagen] Pantalla con el error «Error 424».")
  end

  it 'una nota de voz llega transcrita' do
    allow_any_instance_of(Assistant::Transcriber).to receive(:call).and_return('busco una camioneta familiar') # rubocop:disable RSpec/AnyInstance
    expect(described_class.call(message_with(:audio))).to eq('[nota de voz] busco una camioneta familiar')
  end

  it 'lo nuestro no se lee (solo lo del cliente) y si no se pudo leer, queda lo que escribió' do
    allow_any_instance_of(Motor2::MediaReader).to receive(:chat).and_return(nil) # rubocop:disable RSpec/AnyInstance
    expect(described_class.call(message_with(:image, type: :outgoing, content: 'catálogo'))).to eq('catálogo')
    expect(described_class.call(message_with(:image, content: 'mira'))).to eq('mira')
  end
end
