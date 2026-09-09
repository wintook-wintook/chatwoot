# frozen_string_literal: true

# proyecto@asistente_agentes_ia
require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::AuditService do
  let(:account) { create(:account) }

  def agente(name, prompt)
    account.tracking_templates.create!(name: name, objective: 'Un objetivo cualquiera',
                                       complementary_prompt: prompt)
  end

  def revisar
    described_class.new(account).call
  end

  before { KnowledgeSource.create!(account: account, source_type: 'article', name: 'Centro de Ayuda', status: 'active') }

  describe 'estados' do
    it 'marca como routed a un agente con ramas que el motor lee' do
      agente('Coordinador', '@ruta(soporte #soporte: no puedo entrar): @buscar_articulo')

      expect(revisar.first).to include(status: :routed, routes: 1, defects: 0)
    end

    # El hallazgo que justifica la lente propia: 0 ramas NO es un defecto acá. Un
    # agente sin ramas es conversacional, un estilo válido y anterior a las @ruta.
    it 'marca como conversational a uno sin ramas y sin defectos' do
      agente('Asesor', '[ROL] Sos un asesor comercial amable. [ESTILO] Breve.')

      expect(revisar.first).to include(status: :conversational, routes: 0, defects: 0)
    end

    it 'marca como empty a uno sin Entrenamiento' do
      agente('Recién creado', '')

      expect(revisar.first).to include(status: :empty, routes: 0)
    end

    # Lo que de verdad hay que encontrar: una directiva suelta en la prosa borra la
    # prosa entera y el agente contesta sin instrucciones, sin error ni log.
    it 'marca como broken al que tiene una directiva suelta en la prosa' do
      agente('Consultor', '[ROL] Sos el consultor. Si no sabés, consultá @discourse.')

      fila = revisar.first
      expect(fila[:status]).to eq(:broken)
      expect(fila[:headline]).to include('@discourse')
    end

    it 'marca como broken al que quiso escribir una rama y no le salió' do
      agente('Soporte', '@ruta(soporte #soporte: no puedo entrar) @buscar_articulo')

      expect(revisar.first).to include(status: :broken)
    end

    it 'marca como broken al que apunta a una fuente que no existe' do
      agente('Soporte', '@ruta(soporte #soporte: no puedo entrar): @buscar_foro(Foro Fantasma)')

      expect(revisar.first[:headline]).to include('no existe en esta cuenta')
    end
  end

  describe 'lo que devuelve' do
    it 'ordena por nombre y trae lo justo para decidir cuál abrir' do
      agente('Zeta', '[ROL] Sos amable.')
      agente('Alfa', '@ruta(soporte #soporte: no puedo entrar): @buscar_articulo')

      filas = revisar

      expect(filas.pluck(:name)).to eq(%w[Alfa Zeta])
      expect(filas.first.keys).to include(:id, :name, :inbox_id, :status, :routes, :defects, :degrading, :headline)
    end

    it 'no mira agentes de otra cuenta' do
      create(:account).tracking_templates.create!(name: 'Ajeno', objective: 'Otro objetivo',
                                                  complementary_prompt: '@discourse')

      expect(revisar).to be_empty
    end

    # Los avisos de "funciona pero mal" se cuentan aparte: no descalifican al agente.
    it 'cuenta los que degradan sin marcar al agente como roto' do
      agente('Soporte', '@ruta(soporte #soporte_inexistente: no puedo entrar): @buscar_articulo')

      fila = revisar.first
      expect(fila[:status]).to eq(:routed)
      expect(fila[:degrading]).to be_positive
    end
  end
end
