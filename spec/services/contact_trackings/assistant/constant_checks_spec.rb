require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::ConstantChecks do
  def findings_for(text)
    findings = ContactTrackings::Assistant::Findings.new
    I18n.with_locale(:es) { described_class.check(text, findings: findings) }
    { blocking: findings.of(:blocking), degrading: findings.of(:degrading) }
  end

  def codes(text) = findings_for(text).values.flatten.pluck(:code)

  let(:bien) do
    <<~TXT
      [VARIABLES]
      SISTEMA = valor

      [DATOS FIJOS]
      EMPRESA = Kontrolya
      Q1 (pregunta) = ¿Qué sistemas utilizas? → guarda en SISTEMA

      [BIENVENIDA]
      Presenta a %EMPRESA% y haz %Q1%. Ofrece 10% de beca.
    TXT
  end

  it 'no avisa nada en un Entrenamiento bien escrito' do
    expect(codes(bien)).to eq([])
  end

  it 'no avisa nada si no hay datos fijos (aunque haya porcentajes)' do
    expect(codes("[ROL]\nOfrece 10% y luego 20% de beca.")).to eq([])
  end

  it 'C1 · cita sin declarar, en rojo, una vez por nombre' do
    r = findings_for("#{bien}\nVisita %WEB% y otra vez %WEB%.")
    expect(r[:blocking].pluck(:code)).to eq([:constant_undeclared])
    expect(r[:blocking].first[:message]).to include('%WEB%').and include('EMPRESA, Q1')
  end

  it 'C2 · declarado y sin citar' do
    r = findings_for(bien.sub("EMPRESA = Kontrolya\n", "EMPRESA = Kontrolya\nPRODUCTO = Facturación\n"))
    expect(r[:degrading].pluck(:code)).to eq([:constant_unused])
    expect(r[:degrading].first[:line]).to eq(6)
  end

  it 'C3 · pregunta que guarda en una variable que no existe' do
    expect(codes(bien.sub('guarda en SISTEMA', 'guarda en ERP'))).to include(:constant_saves_unknown)
  end

  it 'C4 · nombre que el sistema no lee, con sugerencia' do
    r = findings_for(bien.sub("EMPRESA = Kontrolya\n", "EMPRESA = Kontrolya\nMi empresa = Otra\n"))
    hallazgo = r[:blocking].find { |f| f[:code] == :constant_bad_name }
    expect(hallazgo[:message]).to include('MI_EMPRESA')
  end

  it 'C4 · nombre repetido' do
    r = findings_for(bien.sub("EMPRESA = Kontrolya\n", "EMPRESA = Kontrolya\nEMPRESA = Otra\n"))
    expect(r[:blocking].pluck(:code)).to include(:constant_duplicate)
  end

  it 'C5 · dos con el mismo contenido' do
    texto = bien.sub("EMPRESA = Kontrolya\n", "EMPRESA = Kontrolya\nLIGA_A = https://zoom.us/r\nLIGA_B = https://zoom.us/r\n")
                .sub('Presenta', 'Usa %LIGA_A% o %LIGA_B%. Presenta')
    r = findings_for(texto)
    expect(r[:degrading].pluck(:code)).to eq([:constant_same_value])
    expect(r[:degrading].first[:message]).to include('LIGA_A, LIGA_B')
  end

  it 'los renglones con sangría de un valor no son nombres malos' do
    texto = bien.sub("EMPRESA = Kontrolya\n", "EMPRESA = Kontrolya\nCIERRE = Gracias\n  Liga = abajo\n")
                .sub('Presenta', '%CIERRE% Presenta')
    expect(codes(texto)).to eq([])
  end
end
