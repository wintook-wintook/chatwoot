# frozen_string_literal: true

require 'rails_helper'

# feat/ficha_agente_ia — ✨ objetivo y contexto con IA (OpenAI simulado: no gasta).
RSpec.describe ContactTrackings::Ficha::Suggester do
  let(:account) { create(:account) }
  let(:offers) { [{ key: 'calendar:1', kind: 'calendar', label: 'Agendar citas' }] }
  let(:chat) { instance_double(ContactTrackings::Assistant::OpenaiChat, api_key: 'sk-x') }

  before { allow(ContactTrackings::Assistant::OpenaiChat).to receive(:new).and_return(chat) }

  def proponer
    described_class.new(account: account, name: 'Grúas', offers: offers, business: 'Renta de grúas').call
  end

  it 'regresa objetivo, contexto un dato por línea (sin pendientes) y lo que falta' do
    allow(chat).to receive(:call).and_return(
      'objective' => 'Atender a los clientes de Grúas.',
      'ai_context' => "Renta de grúas en Monterrey. Atendemos de lunes a sábado.\n<PENDIENTE: teléfono>",
      'missing' => ['Horario de atención', '', 'dirección']
    )

    expect(proponer).to eq(objective: 'Atender a los clientes de Grúas.',
                           ai_context: "Renta de grúas en Monterrey.\nAtendemos de lunes a sábado.",
                           missing: ['horario de atención', 'dirección'])
    expect(chat).to have_received(:call).with(array_including(hash_including(role: 'user', content: include('Agendar citas', 'Renta de grúas'))),
                                              hash_including(model: 'gpt-4o'))
  end

  it 'sin OpenAI o si la llamada falla, nil' do
    allow(chat).to receive(:call).and_return(nil)
    expect(proponer).to be_nil

    allow(chat).to receive(:api_key).and_return(nil)
    expect(proponer).to be_nil
  end

  it 'en modo bienvenida propone o mejora el texto, sin llaves de archivo' do
    allow(chat).to receive(:call).and_return('welcome' => "¡Hola! Te comparto el catálogo {{catalogo}}\n¿Qué necesitas?")
    propuesta = described_class.new(account: account, name: 'Grúas', offers: offers, welcome: 'hola', welcome_files: %w[catalogo],
                                    display_name: 'Sofía').call(:welcome)

    expect(propuesta).to eq(welcome: "¡Hola! Te comparto el catálogo\n¿Qué necesitas?")
    expect(chat).to have_received(:call).with(array_including(hash_including(role: 'user', content: include('Sofía', 'catalogo', 'hola'))),
                                              hash_including(model: 'gpt-4o'))
  end
end
