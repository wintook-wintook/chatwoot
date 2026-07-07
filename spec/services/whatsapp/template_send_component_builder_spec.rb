# frozen_string_literal: true

require 'rails_helper'

# @waba_templates — objeto `template` de ENVÍO (snapshot). Distinto del de creación.
RSpec.describe Whatsapp::TemplateSendComponentBuilder do
  def send_payload(template_attrs, params)
    described_class.call(WhatsappTemplate.new(template_attrs), params)
  end

  it 'rellena body con valores de texto' do
    payload = send_payload(
      { name: 'cobro', language: 'es', body_text: 'Hola {{1}} {{2}}' },
      { body: %w[Juan $100] }
    )
    expect(payload).to eq(
      name: 'cobro',
      language: { policy: 'deterministic', code: 'es' },
      components: [
        { type: 'body', parameters: [{ type: 'text', text: 'Juan' }, { type: 'text', text: '$100' }] }
      ]
    )
  end

  it 'cabecera multimedia va como link (nunca handle)' do
    payload = send_payload(
      { name: 't', language: 'es', header_type: 'image', body_text: 'x' },
      { header: 'https://cdn/x.png', body: ['x'] }
    )
    header = payload[:components].first
    expect(header).to eq(type: 'header', parameters: [{ type: 'image', image: { link: 'https://cdn/x.png' } }])
    expect(payload.to_json).not_to include('handle')
  end

  it 'cabecera de texto va como parámetro text' do
    payload = send_payload(
      { name: 't', language: 'es', header_type: 'text', body_text: 'x' },
      { header: 'Juan', body: ['x'] }
    )
    expect(payload[:components].first).to eq(type: 'header', parameters: [{ type: 'text', text: 'Juan' }])
  end

  it 'botón URL con variable y COPY_CODE' do
    payload = send_payload(
      { name: 't', language: 'es', body_text: 'x' },
      {
        body: ['x'],
        buttons: [
          { index: 0, sub_type: 'url', text: 'abc' },
          { index: 1, sub_type: 'copy_code', coupon_code: 'PROMO10' }
        ]
      }
    )
    buttons = payload[:components].select { |c| c[:type] == 'button' }
    expect(buttons).to eq(
      [
        { type: 'button', sub_type: 'url', index: '0', parameters: [{ type: 'text', text: 'abc' }] },
        { type: 'button', sub_type: 'copy_code', index: '1', parameters: [{ type: 'coupon_code', coupon_code: 'PROMO10' }] }
      ]
    )
  end

  it 'sin variables ni media: solo name y language' do
    payload = send_payload({ name: 't', language: 'es', body_text: 'fijo' }, {})
    expect(payload).to eq(name: 't', language: { policy: 'deterministic', code: 'es' }, components: [])
  end
end
