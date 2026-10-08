# frozen_string_literal: true

require 'rails_helper'

# proyecto@asistente_agentes_ia — referencias entre secciones (24/09/2026)
RSpec.describe ContactTrackings::Assistant::SectionRefs do
  around { |example| I18n.with_locale(:es) { example.run } }

  let(:base) do
    <<~TXT
      [6. CUANDO NO HAY INFORMACIÓN]
      ASESORÍA sin objeción: indícalo y asigna asesor.
      OBJECIONES: responde breve.

      [8. ASESORÍA]
      Si no encuentra: consulta → [6] ASESORÍA; objeción → [6] OBJECIONES.

      [10. CIERRE]
      [PRECIO / INICIO ECONÓMICO]
      Informa el precio normal.

      [14. CONTROL]
      - CONSULTA ECONÓMICA → [10] PRECIO.
      - FRENO → aplica [8. ASESORÍA].
      - SOLICITUD HUMANA → [SI PIDE HUMANO].

      [SI PIDE HUMANO]
      Asigna asesor.
    TXT
  end

  def hallazgos(texto)
    findings = ContactTrackings::Assistant::Findings.new
    described_class.check(texto, findings: findings)
    findings.of(:degrading).map { |f| [f[:code], f[:wrote]] }
  end

  it 'no marca nada cuando todas las referencias apuntan a algo que existe' do
    expect(hallazgos(base)).to be_empty
  end

  it 'marca el número que no existe, el título que cambió, la parte que no está y el nombre que no existe' do
    roto = base.sub('→ [6] OBJECIONES', '→ [16] OBJECIONES').sub('aplica [8. ASESORÍA]', 'aplica [8. ORIENTACION]')
               .sub('[10] PRECIO', '[10] DESCUENTOS').sub('→ [SI PIDE HUMANO]', '→ [HABLAR CON HUMANO]')

    expect(hallazgos(roto)).to contain_exactly(
      [:section_ref_missing, '[16]'], [:section_ref_title, '[8. ORIENTACION]'],
      [:section_ref_part, '[10] DESCUENTOS'], [:section_ref_name, '[HABLAR CON HUMANO]']
    )
  end

  it 'un rótulo con su texto en la misma línea no es una cita' do
    expect(hallazgos("[ROL] Soy el agente.\n[ESTILO] Breve.")).to be_empty
  end

  it 'sin secciones numeradas no revisa números' do
    expect(hallazgos("[ROL]\nVer el punto [3] del contrato.")).to be_empty
  end
end
