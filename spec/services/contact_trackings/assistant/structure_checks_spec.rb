# frozen_string_literal: true

require 'rails_helper'

# proyecto@asistente_agentes_ia — lo mal escrito a mano fuera de las rutas
RSpec.describe ContactTrackings::Assistant::StructureChecks do
  around { |example| I18n.with_locale(:es) { example.run } }

  def hallazgos(texto)
    findings = ContactTrackings::Assistant::Findings.new
    described_class.check(texto, findings: findings)
    (findings.of(:blocking) + findings.of(:degrading)).map { |f| [f[:code], f[:line]] }
  end

  describe 'S1 · rótulo de sección roto' do
    it 'marca «[ROL», «ROL]» y «[[ROL]]», con su línea' do
      expect(hallazgos("[ROL\nSoy el agente.")).to eq([[:section_header_broken, 1]])
      expect(hallazgos("x\nROL]\nSoy el agente.")).to eq([[:section_header_broken, 2]])
      expect(hallazgos("[[ROL]]\nx")).to eq([[:section_header_broken, 1]])
    end

    it 'es rojo y dice qué corchete falta' do
      findings = ContactTrackings::Assistant::Findings.new
      described_class.check("[ESTILO\nEscribo cálido.", findings: findings)

      expect(findings.of(:blocking).first[:message]).to include('falta el «]» de cierre', 'Va así: [ESTILO]')
    end

    it 'no marca un rótulo bien escrito ni texto con corchetes' do
      expect(hallazgos("[ROL]\nVer [aquí](https://x.com) y [x] hecho.\nTermina así ver nota].")).to be_empty
    end
  end

  it 'S2 · marca en rojo la rama por defecto sin «:»' do
    findings = ContactTrackings::Assistant::Findings.new
    described_class.check('@ruta_por_defecto soporte', findings: findings)

    expect(findings.of(:blocking).pluck(:code)).to eq([:default_route_line_broken])
  end

  it 'S3 · marca la segunda vez que aparece una sección' do
    expect(hallazgos("[ROL]\nA\n\n[rol]\nB")).to eq([[:duplicate_section, 4]])
  end

  it 'S4 · marca un «PENDIENTE:» suelto, no la marca con < >' do
    expect(hallazgos("PENDIENTE: qué grupo usar\n<PENDIENTE: tono>")).to eq([[:loose_pending_note, 1]])
  end
end
