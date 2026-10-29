# frozen_string_literal: true

require 'rails_helper'

# prospeccion F1 (docs/prospeccion_estudio.md §9) — asunto del correo que abre el Agente IA.
RSpec.describe TrackingCampaigns::EmailSubject do
  let(:contact) { build(:contact, name: 'Juan Pérez', additional_attributes: { 'company_name' => 'Grúas del Norte' }) }

  it 'arma {{contacto}} con el primer nombre y {{empresa}} con la empresa' do
    expect(described_class.render('{{contacto}}, una idea para {{empresa}}', contact))
      .to eq('Juan, una idea para Grúas del Norte')
  end

  it 'si falta un dato, la variable desaparece sin dejar comas ni espacios sueltos' do
    contact.name = ''
    contact.additional_attributes = {}

    expect(described_class.render('{{contacto}}, una idea para ti', contact)).to eq('Una idea para ti')
    expect(described_class.render('Hola {{contacto}}, ¿te interesa?', contact)).to eq('Hola, ¿te interesa?')
  end

  it 'respeta el texto tal cual cuando no quita nada' do
    expect(described_class.render('una idea rápida', contact)).to eq('una idea rápida')
  end

  it 'vacío o solo variables sin datos = sin asunto (el mailer pone el suyo)' do
    contact.name = ''
    expect(described_class.render('', contact)).to be_nil
    expect(described_class.render('{{contacto}}', contact)).to be_nil
  end

  it "no pasa de #{described_class::MAX_LENGTH} caracteres" do
    expect(described_class.render('a' * 300, contact).length).to eq(described_class::MAX_LENGTH)
  end
end
