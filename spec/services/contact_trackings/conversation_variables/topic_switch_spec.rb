# frozen_string_literal: true

require 'rails_helper'

# 11/11/2026 (cuenta 1128, conv 235): el cliente volvió a Psicología y CARRERA se quedó en
# Bienes Raíces.
RSpec.describe ContactTrackings::ConversationVariables::TopicSwitch do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:prompt) { "[VARIABLES]\nCARRERA = VACÍO | valor\nPRECIO_DADO = NO | SI\nInicial: CARRERA=VACÍO; PRECIO_DADO=NO" }
  let(:tracking) { create(:contact_tracking, account: account, contact: contact, inbox: inbox, complementary_prompt: prompt) }
  let(:bienes_raices) { 'Licenciatura en Desarrollo y Administración Inmobiliaria en Bienes Raíces' }

  before do
    ['Licenciatura en Administración', 'Licenciatura en Psicología', 'Licenciatura en Trabajo Social', bienes_raices,
     'Licenciaturas: formas de titulación'].each do |titulo|
      create(:canned_response, account: account, short_code: titulo)
    end
  end

  def cambios(pregunta, carrera)
    ContactTrackings::ConversationVariables.apply!(tracking, conversation, { 'CARRERA' => carrera })
    described_class.changes_for(tracking, conversation, pregunta, account.id)
  end

  it 'cambia la carrera cuando el cliente nombra otra' do
    expect(cambios('¿Qué es lo que se ve en la licenciatura de psicología?', bienes_raices))
      .to eq('CARRERA' => 'Licenciatura en Psicología')
  end

  it 'reconoce el valor guardado en corto' do
    expect(cambios('y la de psicologia cuanto cuesta', 'Licenciatura en Bienes Raíces')).to eq('CARRERA' => 'Licenciatura en Psicología')
  end

  it 'no cambia nada si el mensaje no nombra otra carrera' do
    expect(cambios('¿Cuánto cuesta el servicio social?', 'Licenciatura en Psicología')).to eq({})
  end

  it 'pide dos palabras propias cuando el título las tiene' do
    expect(cambios('¿Y la titulación es social?', 'Licenciatura en Psicología')).to eq({})
    expect(cambios('Mejor trabajo social', 'Licenciatura en Psicología')).to eq('CARRERA' => 'Licenciatura en Trabajo Social')
  end

  it 'distingue dos carreras que comparten una palabra' do
    expect(cambios('administración', 'Licenciatura en Psicología')).to eq('CARRERA' => 'Licenciatura en Administración')
    expect(cambios('administración inmobiliaria', 'Licenciatura en Psicología')).to eq('CARRERA' => bienes_raices)
  end

  it 'no toca la variable si está en su valor declarado' do
    expect(cambios('licenciatura de psicología', 'VACÍO')).to eq({})
  end
end
