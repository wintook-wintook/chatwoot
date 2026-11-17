# frozen_string_literal: true

require 'rails_helper'

# Motor 2.0 — «Pasar a 2.0»: el mismo agente cambia de motor; su Entrenamiento 1.0 se queda.
RSpec.describe Motor2::Convert do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:prompt) { "[MENSAJE DE BIENVENIDA]\n¡Hola! Soy Sofi.\n\n[ROL]\nAtiendes alumnos. @ruta becas: @buscar_predefinidas" }
  let(:template) { create(:tracking_template, account: account, complementary_prompt: prompt) }

  before do
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' })
  end

  it 'con el modelo: instrucciones en texto libre, datos, preguntas y ofertas; el Entrenamiento 1.0 sigue ahí' do
    converter = described_class.new(template, user: user)
    allow(converter).to receive(:chat).and_return(
      'instructions' => 'Atiendes alumnos que preguntan por becas.', 'tone' => 'usted',
      'business' => [{ 'label' => 'Horario', 'value' => 'L-V 9 a 18' }],
      'data_fields' => [{ 'label' => 'Carrera', 'ask' => true, 'values' => %w[Derecho] }],
      'offers' => { 'objection' => 'está caro', 'steps' => ['Beca de 20%', 'Beca de 35%'] }, 'handoff_when' => 'pide asesor'
    )
    converter.call

    template.reload
    expect(template.engine).to eq('2')
    expect(template.complementary_prompt).to eq(prompt)
    expect(template.motor2).to include('instructions' => 'Atiendes alumnos que preguntan por becas.', 'tone' => 'usted',
                                       'welcome' => '¡Hola! Soy Sofi.')
    expect(template.motor2.dig('skills', 'offers', 'steps').pluck('text')).to eq(['Beca de 20%', 'Beca de 35%'])
    expect(template.motor2.dig('skills', 'data', 'fields', 0)).to include('key' => 'carrera', 'ask' => true)
    expect(Motor2Version.where(tracking_template: template).last.source).to eq('convert')
  end

  it 'sin respuesta del modelo: el Entrenamiento sin directivas' do
    converter = described_class.new(template, user: user)
    allow(converter).to receive(:chat).and_return(nil)
    converter.call
    expect(template.reload.motor2['instructions']).not_to include('@ruta', '@buscar_predefinidas')
  end
end
