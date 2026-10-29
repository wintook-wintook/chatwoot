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
end
