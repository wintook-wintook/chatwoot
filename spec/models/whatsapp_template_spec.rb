# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WhatsappTemplate do
  # feat/plantillas_whatsapp_mejoras F0: el handle de un video de Meta pasa de 255 caracteres.
  it 'acepta el handle largo de una muestra de video' do
    template = build(:whatsapp_template, header_type: 'video', header_handle: "4::#{'a' * 600}")

    expect(template).to be_valid
  end

  it 'no acepta un handle desmedido' do
    template = build(:whatsapp_template, header_type: 'video', header_handle: 'a' * 4001)

    expect(template).not_to be_valid
  end

  # feat/plantillas_whatsapp_mejoras F6
  describe '#header_media_link' do
    it 'sin archivo subido es la liga pegada a mano' do
      expect(build(:whatsapp_template, header_media_url: 'https://cdn.mx/f.pdf').header_media_link).to eq('https://cdn.mx/f.pdf')
    end

    it 'con archivo subido es una liga fresca suya, aunque haya una pegada' do
      canal = create(:channel_whatsapp, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false)
      template = create(:whatsapp_template, channel_whatsapp: canal, account: canal.account, header_type: 'document',
                                            header_media_url: 'https://cdn.mx/viejo.pdf')
      template.header_sample.attach(io: Rails.root.join('spec/assets/sample.pdf').open, filename: 'Factura.pdf',
                                    content_type: 'application/pdf')

      expect(template.header_media_link).to include('/rails/active_storage/').and include('Factura.pdf')
    end
  end
end
