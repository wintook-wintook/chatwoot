require 'rails_helper'

RSpec.describe ContactTrackings::SheetLookup::Pages do
  describe '.asks_more?' do
    let(:ofrecio) { "…\n\nTenemos 5 más, ¿quieres verlas?" }
    let(:no_ofrecio) { "…\n\n¿Te gustaría verlo físicamente?" }

    it 'reconoce cuando pide las demás' do
      ['¿cuáles son las otras?', 'mándame el resto', 'quiero ver más', '¿hay más opciones?', 'y las demás?'].each do |texto|
        expect(described_class.asks_more?(texto, no_ofrecio)).to be(true), texto
      end
    end

    it 'no confunde otra pregunta con pedir más' do
      ['¿y el más barato?', 'algo más económico', '¿tienen más de 2020?'].each do |texto|
        expect(described_class.asks_more?(texto, ofrecio)).to be(false), texto
      end
    end

    it 'un «sí» solo cuenta si el agente ofreció ver las demás' do
      expect(described_class.asks_more?('Sí, por favor', ofrecio)).to be(true)
      expect(described_class.asks_more?('sí', no_ofrecio)).to be(false)
    end
  end
end
