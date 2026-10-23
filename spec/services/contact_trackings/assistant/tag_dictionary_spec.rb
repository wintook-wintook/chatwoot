# frozen_string_literal: true

require 'rails_helper'

# proyecto@asistente_agentes_ia — las etiquetas como estados
RSpec.describe ContactTrackings::Assistant::TagDictionary do
  let(:account) { create(:account) }

  around { |example| I18n.with_locale(:es) { example.run } }

  def hallazgos(texto)
    findings = ContactTrackings::Assistant::Findings.new
    described_class.check(texto, findings: findings)
    findings.of(:degrading).map { |f| [f[:code], f[:line]] }
  end

  describe '.declared' do
    it 'toma las del diccionario y las que cierran una sección con texto' do
      texto = "@ruta(cotizacion #cotizar1: quiero cotizar): -\n\n[COTIZACION]\nSi ya se entiende, canaliza.\n#cotizar2\n\n" \
              "[ETIQUETAS]\n#comercial1 = información respondida"

      expect(described_class.declared(texto)).to eq(%w[#cotizar2 #comercial1])
    end

    it 'no toma la suelta de una sección sin texto' do
      expect(described_class.declared("[ETIQUETAS]\n#humano")).to be_empty
    end

    it 'no confunde un encabezado Markdown ni un número con una etiqueta' do
      expect(described_class.declared("# ROL\nPedido #123 listo.")).to be_empty
    end
  end

  it 'avisa la etiqueta suelta, sin significado (la 173)' do
    expect(hallazgos("[ETIQUETAS]\n#humano\n\n[ESTILO]\nBreve.")).to include([:bare_tag_line, 2])
  end

  it 'no revisa que la etiqueta de estado exista en la cuenta (va en el mensaje)' do
    expect(hallazgos("[ETIQUETAS]\n#comercial1 = respondida\n#comercial3 = canalizar")).to be_empty
  end
end
