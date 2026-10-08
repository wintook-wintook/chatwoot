# frozen_string_literal: true

require 'rails_helper'

# proyecto@asistente_agentes_ia — la única tabla de herramientas del encargo contra el motor.
RSpec.describe ContactTrackings::Assistant::BriefTools do
  let(:account) { create(:account) }
  let(:inventario) { ContactTrackings::Assistant::InventoryService.new(account).call }

  # Falla a propósito cuando el motor gana un tipo de fuente y nadie le da nombre en la
  # ficha del encargo: sin esto, el lector lo anotaría como "otra" para siempre.
  it 'nombra cada tipo de fuente que el Asistente sabe ofrecer' do
    ofrecidos = ContactTrackings::Assistant::InventoryService::SOURCE_DIRECTIVES.keys

    expect(described_class::SOURCES.values).to match_array(ofrecidos)
  end

  it 'da las directivas exactas de las fuentes que la cuenta tiene conectadas' do
    KnowledgeSource.create!(account: account, source_type: 'google_sheet', name: 'Cartera vencida', status: 'active')

    expect(described_class.directives('hoja', inventario)).to eq(['{{hoja:Cartera vencida}}'])
    expect(described_class.available?('documento', inventario)).to be(false)
  end

  it 'arma @crear_ticket con los tipos de caso de la cuenta' do
    CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6')

    expect(described_class.directives('ticket', inventario)).to eq(['@crear_ticket(tipo=Soporte)'])
  end

  it 'no cruza con la cuenta lo que no depende de ella' do
    expect(described_class.available?('persona', inventario)).to be_nil
  end

  it 'arma la gramática del lector desde la del motor' do
    expect(described_class.grammar).to include('{{hoja:…}} → hoja', '@buscar_predefinidas → predefinidas')
  end
end
