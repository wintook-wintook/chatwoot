# frozen_string_literal: true

# proyecto@adaptar_prompts_publicados (F7)
require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::VariableSuggestions do
  let(:account) { create(:account) }
  let(:texto) do
    "@ruta(ventas: precios): {{doc:Grúas del Norte}}\n" \
      'Eres el asistente de Grúas del Norte. Atendemos de L-V 9 a 18. Llama al 81 1234 5678.'
  end
  let(:chat) { instance_double(ContactTrackings::Assistant::OpenaiChat, api_key: 'sk-test') }

  before { allow(ContactTrackings::Assistant::OpenaiChat).to receive(:new).and_return(chat) }

  def proponer(variables)
    allow(chat).to receive(:call).and_return('variables' => variables)
    described_class.new(texto, account: account).call
  end

  it 'deja solo lo que aparece tal cual en la prosa, con cuántas veces' do
    resultado = proponer([
                           { 'text' => 'Grúas del Norte', 'label' => 'Nombre del negocio' },
                           { 'text' => 'L-V 9 a 18', 'label' => 'Horario' },
                           { 'text' => 'Monterrey', 'label' => 'Ciudad' }, # inventado: no está
                           { 'text' => '81', 'label' => 'Lada' } # muy corto
                         ])

    expect(resultado.variables).to eq([
                                        { 'text' => 'Grúas del Norte', 'label' => 'Nombre del negocio', 'count' => 1 },
                                        { 'text' => 'L-V 9 a 18', 'label' => 'Horario', 'count' => 1 }
                                      ])
  end

  it 'limpia el nombre (sin < >) y si viene vacío usa el texto' do
    resultado = proponer([{ 'text' => '81 1234 5678', 'label' => '<Teléfono>' }, { 'text' => 'L-V 9 a 18', 'label' => '' }])

    expect(resultado.variables.pluck('label')).to eq(['Teléfono', 'L-V 9 a 18'])
  end

  it 'sin la integración de OpenAI no llama y lo dice' do
    allow(chat).to receive(:api_key).and_return(nil)
    expect(chat).not_to receive(:call)

    expect(described_class.new(texto, account: account).call).to have_attributes(variables: [], error: 'no_api_key')
  end

  it 'si el modelo falla, lo dice' do
    allow(chat).to receive(:call).and_return(nil)

    expect(described_class.new(texto, account: account).call.error).to eq('failed')
  end
end
