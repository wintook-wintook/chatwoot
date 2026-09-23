# frozen_string_literal: true

require 'rails_helper'

# proyecto@asistente_agentes_ia — la pestaña Recursos: lo que ofrece el motor.
RSpec.describe ContactTrackings::Assistant::EngineCatalog do
  let(:account) { create(:account) }
  let(:inventario) { ContactTrackings::Assistant::InventoryService.new(account).call }
  let(:fichas) { described_class.new(inventario).call.index_by { |f| f[:key] } }

  # Falla a propósito cuando el motor gana una fuente de búsqueda y nadie le hace
  # ficha: sin esto, la fuente existiría y la pantalla no la mostraría nunca.
  it 'tiene una ficha por cada fuente de búsqueda del motor' do
    modos = KnowledgeBase::Directives::SEARCH_DIRECTIVES.map(&:second)

    expect(described_class::SEARCH_MODES.keys).to match_array(modos)
    expect(described_class::CARDS.keys).to include(*described_class::SEARCH_MODES.values)
  end

  # Los textos de cada ficha viven en el i18n de la pantalla, en los dos idiomas.
  it 'cada ficha tiene su texto en español y en inglés' do
    partes = %w[WHAT NEEDS]
    %w[es en].each do |idioma|
      textos = JSON.parse(Rails.root.join("app/javascript/dashboard/i18n/locale/#{idioma}/trackingAssistant.json").read)
      vista = textos['TRACKING_ASSISTANT_VIEW']
      faltan = described_class::CARDS.keys.flat_map do |key|
        partes.map { |parte| "CATALOG_#{key.upcase}_#{parte}" }.reject { |clave| vista.key?(clave) }
      end
      expect(faltan).to eq([]), "#{idioma}: faltan #{faltan.join(', ')}"
    end
  end

  it 'marca lista una fuente conectada, con su nombre exacto para copiar' do
    KnowledgeSource.create!(account: account, source_type: 'google_sheet', name: 'Precios', status: 'active')

    expect(fichas['hoja']).to include(status: 'ready', items: ['{{hoja:Precios}}'])
    expect(fichas['doc']).to include(status: 'missing', items: [])
  end

  it 'ofrece @crear_ticket con los tipos de caso de la cuenta' do
    CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6')

    expect(fichas['crear_ticket']).to include(status: 'ready', items: ['@crear_ticket(tipo=Soporte)'])
  end

  it 'la gramática del Entrenamiento siempre está, y el adjunto depende del agente' do
    expect(fichas.values_at('ruta', 'seccion', 'etiqueta').pluck(:status)).to all(eq('ready'))
    expect(fichas['adjunto'][:status]).to eq('depends')
  end
end
