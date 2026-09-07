# frozen_string_literal: true

# proyecto@contact_tracking — @ruta
require 'rails_helper'

RSpec.describe ContactTrackings::RouteMap do
  let(:prompt) do
    <<~TXT
      # AGENTE V3.0
      @ruta(soporte: fallas, errores, integraciones): @discourse
      @ruta(comercial: precios, licencias): {{hoja:Info Licencia}}
      @ruta(administrativo: facturas, RFC): -
      @ruta_por_defecto: comercial

      [ROL]
      Atiendes clientes.
    TXT
  end

  describe '.parse' do
    subject(:map) { described_class.parse(prompt) }

    it 'reconoce todas las ramas declaradas, en orden' do
      expect(map.names).to eq(%w[soporte comercial administrativo])
    end

    it 'asocia cada rama con su directiva' do
      expect(map['soporte'].directive).to eq('@discourse')
      expect(map['comercial'].directive).to eq('{{hoja:Info Licencia}}')
    end

    it 'trata el guion como rama sin fuente' do
      expect(map['administrativo'].source?).to be(false)
      expect(map['administrativo'].directive).to be_nil
    end

    it 'guarda la descripción para el clasificador' do
      expect(map.catalog.first).to eq('soporte: fallas, errores, integraciones')
    end

    it 'resuelve la rama por defecto declarada' do
      expect(map.default.name).to eq('comercial')
    end

    it 'busca ramas sin distinguir mayúsculas ni espacios' do
      expect(map[' SOPORTE ']).to eq(map['soporte'])
    end

    it 'ignora una rama por defecto que no está declarada' do
      other = described_class.parse("@ruta(uno): @discourse\n@ruta_por_defecto: inexistente")
      expect(other.default).to be_nil
    end

    it 'admite un número libre de ramas' do
      many = described_class.parse((1..7).map { |i| "@ruta(rama#{i}): @discourse" }.join("\n"))
      expect(many.names.size).to eq(7)
    end

    it 'queda vacío cuando el prompt no declara rutas' do
      expect(described_class.parse('@discourse sin rutas')).not_to be_present
    end

    it 'no explota con texto vacío o nil' do
      expect(described_class.parse(nil)).not_to be_present
      expect(described_class.parse('')).not_to be_present
    end
  end

  describe 'escalamiento por rama' do
    subject(:map) { described_class.parse(con_flechas) }

    let(:con_flechas) do
      <<~TXT
        @ruta(soporte: fallas): @discourse -> @crear_ticket(tipo=Soporte)
        @ruta(comercial: precios): {{hoja:Info Licencia}} => @crear_ticket(tipo=Comercial, prioridad=alta)
        @ruta(administrativo: facturas): - → @crear_ticket(tipo=Administrativo)
        @ruta(otra: lo demas): @discourse
      TXT
    end

    it 'separa la fuente del escalamiento' do
      expect(map['soporte'].directive).to eq('@discourse')
      expect(map['soporte'].escalation).to eq('@crear_ticket(tipo=Soporte)')
    end

    it 'acepta las tres formas de flecha' do
      expect(map['comercial'].escalation).to eq('@crear_ticket(tipo=Comercial, prioridad=alta)')
      expect(map['administrativo'].escalation).to eq('@crear_ticket(tipo=Administrativo)')
    end

    it 'permite escalar una rama que no consulta ninguna fuente' do
      expect(map['administrativo'].source?).to be(false)
      expect(map['administrativo'].escalates?).to be(true)
    end

    it 'deja sin escalamiento la rama que no declara flecha' do
      expect(map['otra'].escalates?).to be(false)
      expect(map['otra'].directive).to eq('@discourse')
    end

    it 'informa si el agente usa escalamiento por rama' do
      expect(map).to be_escalations
      expect(described_class.parse('@ruta(uno): @discourse')).not_to be_escalations
    end
  end

  describe '.strip' do
    it 'quita las líneas de configuración y conserva la prosa' do
      cleaned = described_class.strip(prompt)

      expect(cleaned).not_to include('@ruta')
      expect(cleaned).to include('[ROL]', 'Atiendes clientes.')
    end

    it 'deja intacto un prompt sin rutas' do
      expect(described_class.strip('@discourse\n[ROL]')).to eq('@discourse\n[ROL]')
    end
  end
end
