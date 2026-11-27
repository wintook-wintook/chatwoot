require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::VariableChecks do
  def findings_for(text)
    findings = ContactTrackings::Assistant::Findings.new
    I18n.with_locale(:es) { described_class.check(text, findings: findings) }
    findings.of(:degrading)
  end

  def codes(text) = findings_for(text).pluck(:code)

  let(:becas) do
    <<~TXT
      [VARIABLES]
      CARRERA = valor
      LIGA_ENTREGADA = NO | SÍ
      Inicial: LIGA_ENTREGADA=NO

      [BECAS]
      Si CARRERA=VACÍO pregunta qué carrera le interesa.
      Ofrece 10% de beca. Al mandar la liga marca LIGA_ENTREGADA=SÍ.
      Liga: https://ejemplo.com/registro?origen=wa&utm=abc
    TXT
  end

  it 'no avisa nada en un Entrenamiento bien escrito (porcentajes y ligas incluidos)' do
    expect(findings_for(becas)).to eq([])
  end

  it 'los datos fijos («EMPRESA = Kontrolya») no son usos de variables' do
    expect(codes("#{becas}\n[DATOS FIJOS]\nEMPRESA = Kontrolya\n\n[DATOS DEL NEGOCIO]\n- Empresa: %EMPRESA%")).to eq([])
  end

  it 'no avisa nada si no hay variables' do
    expect(findings_for("[ROL]\nEres el agente de ventas.")).to eq([])
  end

  describe 'V5 · declaradas fuera de [VARIABLES]' do
    let(:dci) do
      <<~TXT
        [3. NÚCLEO DCI]
        Registra y actualiza silenciosamente:
        * OBJETIVO_COMERCIAL = VACIO | valor
        * CIERRE_ENVIADO = NO | SI
      TXT
    end

    it 'avisa cada renglón, con su línea, aunque no exista [VARIABLES]' do
      items = findings_for(dci)
      expect(items.pluck(:code)).to eq(%i[variables_outside_section variables_outside_section])
      expect(items.pluck(:line)).to eq([3, 4])
      expect(items.first[:message]).to include('OBJETIVO_COMERCIAL').and include('[VARIABLES]')
    end

    it 'nombra todas las de un renglón con varias' do
      items = findings_for("[ESTADOS]\nCARRERA=VACÍO|valor; LIGA_ENTREGADA=NO|SÍ; REVALIDACIÓN=NO|SÍ.")
      expect(items.size).to eq(1)
      expect(items.first[:message]).to include('CARRERA, LIGA_ENTREGADA, REVALIDACIÓN')
    end

    it 'no avisa las que sí están dentro de [VARIABLES]' do
      expect(codes(becas)).not_to include(:variables_outside_section)
    end

    it 'expone los renglones para «Pasarlas a Variables»' do
      expect(ContactTrackings::Assistant::StrayVariables.lines(dci).pluck(:line, :names))
        .to eq([[3, ['OBJETIVO_COMERCIAL']], [4, ['CIERRE_ENVIADO']]])
    end
  end

  describe 'V1 · se usa y no está declarada' do
    it 'avisa una vez por nombre, en la primera línea' do
      items = findings_for("#{becas}\nSi BECA=SÍ ofrece la segunda.\nMarca BECA=NO al final.")
      v1 = items.select { |i| i[:code] == :variable_undeclared }
      expect(v1.size).to eq(1)
      expect(v1.first[:message]).to include('BECA').and include('CARRERA, LIGA_ENTREGADA')
    end
  end

  describe 'V2 · declarada y sin usar' do
    it 'avisa en la línea de su declaración' do
      texto = becas.sub("LIGA_ENTREGADA = NO | SÍ\n", "LIGA_ENTREGADA = NO | SÍ\nINTERES = ALTO | BAJO\n")
      v2 = findings_for(texto).select { |i| i[:code] == :variable_unused }
      expect(v2.pluck(:line)).to eq([4])
      expect(v2.first[:message]).to include('INTERES')
    end
  end

  describe 'V3 · valor fuera de su lista' do
    it 'avisa el valor que el motor descartaría' do
      v3 = findings_for(becas.sub('LIGA_ENTREGADA=SÍ', 'LIGA_ENTREGADA=ENVIADA'))
           .select { |i| i[:code] == :variable_value_unknown }
      expect(v3.size).to eq(1)
      expect(v3.first[:message]).to include('ENVIADA').and include('NO | SÍ')
    end

    it 'acepta el valor sin acento (SI por SÍ) y cualquier valor en las de texto libre' do
      texto = becas.sub('LIGA_ENTREGADA=SÍ', 'LIGA_ENTREGADA=SI').sub('CARRERA=VACÍO', 'CARRERA=Psicología')
      expect(codes(texto)).not_to include(:variable_value_unknown)
    end
  end

  describe 'V4 · valor inicial' do
    it 'avisa el inicial que no está en la lista' do
      v4 = findings_for(becas.sub('Inicial: LIGA_ENTREGADA=NO', 'Inicial: LIGA_ENTREGADA=TAL_VEZ'))
           .select { |i| i[:code] == :variable_initial_invalid }
      expect(v4.size).to eq(1)
      expect(v4.first[:message]).to include('«NO»')
    end

    it 'avisa el inicial de una variable que no existe' do
      texto = becas.sub('Inicial: LIGA_ENTREGADA=NO', 'Inicial: LIGA_ENTREGADA=NO; FANTASMA=SÍ')
      expect(codes(texto)).to include(:variable_initial_invalid)
    end
  end

  it 'el comprobador los entrega como ámbar' do
    result = ContactTrackings::Assistant::ValidatorService.new("[ESTADOS]\n* TIPO = A | B\n", account: create(:account)).call
    expect(result[:degrading].pluck(:code)).to include(:variables_outside_section)
    expect(result[:blocking].pluck(:code)).not_to include(:variables_outside_section)
  end
end
