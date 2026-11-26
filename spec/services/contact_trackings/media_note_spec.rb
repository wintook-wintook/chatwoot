# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContactTrackings::MediaNote do
  let(:message) { create(:message) }

  def con_adjunto(tipo)
    message.attachments.new(account_id: message.account_id, file_type: tipo)
    message
  end

  it 'marca imágenes y videos, no documentos' do
    expect(described_class.with_marks('¿Sigue disponible?', con_adjunto(:image))).to eq('¿Sigue disponible? [el cliente envió una imagen]')
    expect(described_class.marks(create(:message))).to eq([])
  end

  it 'da la regla solo si el turno trae una marca' do
    expect(described_class.rule('hola [el cliente envió una imagen]')).to include('NO puedes verlo')
    expect(described_class.rule('hola')).to be_nil
  end
end
