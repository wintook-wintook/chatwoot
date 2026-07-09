# frozen_string_literal: true

require 'rails_helper'

# @waba_templates — payload de CREACIÓN de plantilla (snapshot).
RSpec.describe Whatsapp::TemplateComponentBuilder do
  def build(**attrs)
    described_class.call(WhatsappTemplate.new(attrs))
  end

  it 'ensambla body con example 2D y sin header/footer/botones' do
    payload = build(
      name: 'cobro_vencido', language: 'es', category: 'UTILITY',
      body_text: 'Hola {{1}}, saldo {{2}}',
      sample_values: { 'body' => %w[Juan $100] }
    )

    expect(payload).to eq(
      name: 'cobro_vencido',
      language: 'es',
      category: 'UTILITY',
      components: [
        { type: 'BODY', text: 'Hola {{1}}, saldo {{2}}', example: { body_text: [%w[Juan $100]] } }
      ]
    )
  end

  it 'mantiene el orden HEADER → BODY → FOOTER → BUTTONS' do
    payload = build(
      name: 'promo', language: 'es', category: 'MARKETING',
      header_type: 'text', header_content: 'Hola {{1}}',
      body_text: 'Cuerpo {{1}}',
      footer_text: 'Gracias',
      buttons: [{ 'type' => 'QUICK_REPLY', 'text' => 'Sí' }],
      sample_values: { 'header' => ['Juan'], 'body' => ['x'] }
    )

    expect(payload[:components].map { |c| c[:type] }).to eq(%w[HEADER BODY FOOTER BUTTONS])
  end

  it 'cabecera de texto con variable incluye example.header_text' do
    payload = build(
      name: 't', language: 'es', category: 'UTILITY',
      header_type: 'text', header_content: 'Hola {{1}}',
      body_text: 'x', sample_values: { 'header' => ['Juan'] }
    )
    header = payload[:components].first
    expect(header).to eq(type: 'HEADER', format: 'TEXT', text: 'Hola {{1}}', example: { header_text: ['Juan'] })
  end

  it 'cabecera multimedia usa header_handle (no url)' do
    payload = build(
      name: 't', language: 'es', category: 'UTILITY',
      header_type: 'image', header_handle: 'h:abc123',
      body_text: 'x'
    )
    header = payload[:components].first
    expect(header).to eq(type: 'HEADER', format: 'IMAGE', example: { header_handle: ['h:abc123'] })
  end

  it 'mapea cada tipo de botón' do
    payload = build(
      name: 't', language: 'es', category: 'UTILITY', body_text: 'x',
      buttons: [
        { 'type' => 'QUICK_REPLY', 'text' => 'Sí' },
        { 'type' => 'URL', 'text' => 'Ver', 'url' => 'https://x/{{1}}', 'example' => ['https://x/abc'] },
        { 'type' => 'PHONE_NUMBER', 'text' => 'Llamar', 'phone_number' => '+5215500000000' },
        { 'type' => 'COPY_CODE', 'example' => ['PROMO10'] }
      ]
    )
    buttons = payload[:components].last
    expect(buttons).to eq(
      type: 'BUTTONS',
      buttons: [
        { type: 'QUICK_REPLY', text: 'Sí' },
        { type: 'URL', text: 'Ver', url: 'https://x/{{1}}', example: ['https://x/abc'] },
        { type: 'PHONE_NUMBER', text: 'Llamar', phone_number: '+5215500000000' },
        { type: 'COPY_CODE', example: 'PROMO10' }
      ]
    )
  end

  it 'body sin variables no incluye example' do
    payload = build(name: 't', language: 'es', category: 'UTILITY', body_text: 'Texto fijo')
    expect(payload[:components].first).to eq(type: 'BODY', text: 'Texto fijo')
  end
end
