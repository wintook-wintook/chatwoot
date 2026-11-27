# frozen_string_literal: true

require 'rails_helper'

# diag/waba F1 — el error de Meta en palabras del usuario.
RSpec.describe Whatsapp::ErrorTranslator do
  around { |example| I18n.with_locale(:es) { example.run } }

  it 'entiende el aviso de estado «código: título»' do
    result = described_class.translate('131047: Re-engagement message')
    expect(result).to include(key: 'window_24h', code: 131_047)
    expect(result[:text]).to include('usa una plantilla')
  end

  it 'entiende la respuesta JSON del envío y usa el detalle de Meta' do
    raw = { error: { message: '(#132001) Template name does not exist', code: 132_001,
                     error_data: { details: 'template promo_nov does not exist in es_MX' } } }.to_json
    result = described_class.translate(raw)
    expect(result).to include(key: 'template', code: 132_001)
    expect(result[:text]).to include('promo_nov')
  end

  it 'token vencido (190) pide reconectar' do
    raw = { error: { message: 'Error validating access token', type: 'OAuthException', code: 190 } }.to_json
    expect(described_class.translate(raw)[:key]).to eq('token')
  end

  it 'lo desconocido dice qué respondió Meta' do
    result = described_class.translate('999999: Algo raro')
    expect(result[:key]).to eq('other')
    expect(result[:text]).to eq('Meta respondió: Algo raro')
    expect(described_class.translate(nil)[:text]).to include('sin detalle')
  end
end
