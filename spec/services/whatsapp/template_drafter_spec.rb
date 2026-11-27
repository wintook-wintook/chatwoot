# frozen_string_literal: true

require 'rails_helper'

# «Crear con IA» de plantillas de WhatsApp: la IA se simula (no se llama a OpenAI).
RSpec.describe Whatsapp::TemplateDrafter do
  let(:account) { create(:account, locale: 'es') }
  let(:drafter) { described_class.new(account: account) }
  let(:reply) do
    { 'name' => 'Ventas Cotización por vencer', 'category' => 'utility', 'category_reason' => 'Da seguimiento a su cotización.',
      'header' => 'Tu cotización', 'body' => 'Hola {{primer_nombre}}, tu cotización vence en 3 días. ¿Te ayudo con algo?',
      'footer' => 'Equipo {{empresa}}', 'buttons' => ['Sí, tengo dudas', 'Ya la revisé', 'Más tarde', 'Otra'],
      'samples' => { 'primer_nombre' => 'Ana' } }
  end

  before { allow(drafter).to receive(:available?).and_return(true) }

  it 'arma el borrador: nombre estructurado, categoría, ejemplos y botones dentro de las reglas' do
    allow(drafter).to receive(:chat).and_return(reply)
    result = drafter.call(goal: 'recordar que la cotización vence en 3 días')

    expect(result[:draft]).to include(name: 'ventas_cotizacion_por_vencer', category: 'UTILITY', header_type: 'text',
                                      footer_text: 'Equipo')
    expect(result[:draft][:sample_values]).to eq('body' => ['Ana'], 'header' => [])
    expect(result[:draft][:buttons].pluck('text')).to eq(['Sí, tengo dudas', 'Ya la revisé', 'Más tarde'])
    expect(result).to include(reason: 'Da seguimiento a su cotización.', warnings: [])
  end

  it 'si el nombre ya existe, le agrega _v2' do
    inbox = create(:inbox, account: account,
                           channel: create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', validate_provider_config: false,
                                                              sync_templates: false,
                                                              message_templates: [{ 'name' => 'ventas_cotizacion_por_vencer' }]))
    expect(inbox).to be_present
    allow(drafter).to receive(:chat).and_return(reply)

    expect(drafter.call(goal: 'x')[:draft][:name]).to eq('ventas_cotizacion_por_vencer_v2')
  end

  it 'si no cumple, pide una corrección a la IA' do
    bad = reply.merge('body' => '{{primer_nombre}} tu cotización vence pronto')
    allow(drafter).to receive(:chat).and_return(bad, reply)

    result = drafter.call(goal: 'x')
    expect(drafter).to have_received(:chat).twice
    expect(result[:warnings]).to eq([])
  end

  it 'sin OpenAI conectado, lo dice' do
    allow(drafter).to receive(:available?).and_return(false)
    expect(drafter.call(goal: 'x')[:error]).to include('OpenAI')
  end
end
