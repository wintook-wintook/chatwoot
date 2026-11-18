# frozen_string_literal: true

require 'rails_helper'

# Probador de agentes — lotes desde una hoja pegada o desde la pila vieja del agente.
RSpec.describe AgentTester::Importer do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:template) { create(:tracking_template, account: account) }
  let(:importer) { described_class.new(template, user: user) }

  it 'una fila por prueba, con varios mensajes, lo que se espera y las variables; salta títulos y filas incompletas' do
    hoja = "Pregunta\tEsperado\tVariables\n" \
           "Hola | ¿cuánto cuesta?\tQue dé el precio normal\tCARRERA=Licenciatura en Derecho; PLAN=Básico\n" \
           "\n" \
           "Solo pregunta sin esperado\t\n" \
           "¿Dónde están?\tQue dé la dirección\n"
    result = importer.from_text(hoja, name: 'Mis preguntas')

    expect(result[:batch]).to have_attributes(name: 'Mis preguntas', tracking_template_id: template.id)
    expect(result[:created]).to eq(2)
    expect(result[:skipped]).to eq([{ line: 4, reason: 'sin lo que se espera' }])
    primera = result[:batch].cases.order(:id).first
    expect(primera).to have_attributes(messages: ['Hola', '¿cuánto cuesta?'], expected: 'Que dé el precio normal', origin: 'import',
                                       variables: { 'CARRERA' => 'Licenciatura en Derecho', 'PLAN' => 'Básico' })
  end

  it 'también con «;» en vez de tabuladores' do
    expect(importer.from_text('¿Abren el domingo?;Que diga el horario')[:created]).to eq(1)
  end

  it 'la pila vieja del agente: sus diálogos y lo que revisa cada prueba' do
    TrackingTestCase.create!(account: account, tracking_template: template, message: 'Hola', turns: ['Hola', '¿precio?'],
                             check_text: 'Da el precio', kind: 'propia')
    TrackingTestCase.create!(account: account, tracking_template: template, message: '¿horario?', expected_route: 'dudas', kind: 'ruta')

    result = importer.from_pila
    casos = result[:batch].cases.order(:id)
    expect(casos.map { |c| [c.messages, c.expected] }).to eq([[['Hola', '¿precio?'], 'Da el precio'],
                                                              [['¿horario?'], 'Que conteste lo de la ruta «dudas»']])
  end
end
