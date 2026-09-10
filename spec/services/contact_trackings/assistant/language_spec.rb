# frozen_string_literal: true

# proyecto@asistente_agentes_ia
require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::Language do
  describe '.resolve' do
    it 'reconoce los dos idiomas soportados' do
      expect(described_class.resolve(:es)).to eq(:es)
      expect(described_class.resolve(:en)).to eq(:en)
    end

    it 'toma la parte de idioma de una variante regional' do
      expect(described_class.resolve('es-MX')).to eq(:es)
      expect(described_class.resolve('en_US')).to eq(:en)
    end

    # Chatwoot tiene decenas de idiomas y el Asistente solo dos. Sin esto, una cuenta
    # en portugués vería "translation missing" en el panel: config.i18n.fallbacks solo
    # está puesto en production y staging, no en desarrollo.
    it 'cae al español con un idioma que no soporta, en vez de romper' do
      expect(described_class.resolve(:pt)).to eq(:es)
      expect(described_class.resolve(:fr)).to eq(:es)
      expect(described_class.resolve(nil)).to eq(:es)
    end
  end

  describe '.name_for' do
    it 'nombra el idioma como se le dice al modelo' do
      expect(described_class.name_for(:es)).to eq('español')
      expect(described_class.name_for(:en)).to eq('English')
    end
  end
end
