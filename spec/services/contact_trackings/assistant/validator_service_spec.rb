# frozen_string_literal: true

# proyecto@asistente_agentes_ia
require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::ValidatorService do
  let(:account) { create(:account) }

  def source(source_type, name)
    KnowledgeSource.create!(account: account, source_type: source_type, name: name, status: 'active')
  end

  def case_type(name)
    CaseType.create!(account: account, name: name, color: '#3b82f6')
  end

  def validar(texto)
    described_class.new(texto, account: account).call
  end

  def codigos(resultado, severidad)
    resultado[severidad].pluck(:code)
  end

  # ── lo que el motor lee ─────────────────────────────────────────────────────
  describe 'lo que el motor va a leer' do
    it 'devuelve cada rama con su etiqueta, su fuente resuelta y su escalamiento' do
      source('discourse', 'Foro Kontrolya')
      case_type('Soporte')

      r = validar(<<~TXT)
        @ruta(soporte #soporte: no puedo entrar, error al abrir): @buscar_foro(Foro Kontrolya) -> @crear_ticket(tipo=Soporte)
        @ruta_por_defecto: soporte
      TXT

      expect(r[:routes]).to contain_exactly(
        hash_including(
          name: 'soporte', tag: '#soporte', mode: :knowledge_source,
          source_name: 'Foro Kontrolya', escalation: '@crear_ticket(tipo=Soporte)'
        )
      )
      expect(r[:default_route]).to eq('soporte')
    end

    it 'acepta una rama sin fuente, que es lo que declara el guion' do
      r = validar('@ruta(saludo #demo: hola, buenas): -')

      expect(r[:routes].first[:directive]).to be_nil
      expect(codigos(r, :blocking)).to be_empty
    end
  end

  # ── B2 · la falla que motivó todo el módulo ─────────────────────────────────
  describe 'B2 · una línea que quiso ser @ruta y el motor no reconoce' do
    # Medido el 08/09/2026: el modelo omitió el ":" y el Entrenamiento parseó a
    # cero ramas, sin error ni log. Decir solo "no hay ramas" no alcanza: hay que
    # decir qué carácter falta y dónde.
    it 'señala el ":" que falta tras el paréntesis de cierre, con la línea y lo escrito' do
      r = validar('@ruta(soporte #soporte: no puedo entrar) @buscar_articulo')

      hallazgo = r[:blocking].find { |f| f[:code] == :route_line_unparsed }
      expect(hallazgo[:line]).to eq(1)
      expect(hallazgo[:message]).to include('falta el ":" inmediatamente después del paréntesis de cierre')
      expect(hallazgo[:wrote]).to start_with('@ruta(soporte')
    end

    it 'señala el paréntesis de cierre cuando es ese el que falta' do
      r = validar('@ruta(soporte #soporte: no puedo entrar: @buscar_articulo')

      expect(r[:blocking].find { |f| f[:code] == :route_line_unparsed }[:message])
        .to include('falta el paréntesis de cierre')
    end

    it 'no repite el genérico "0 ramas" cuando ya explicó línea por línea' do
      r = validar('@ruta(soporte #soporte: no puedo entrar) @buscar_articulo')

      expect(codigos(r, :blocking)).to include(:route_line_unparsed)
      expect(codigos(r, :blocking)).not_to include(:no_routes)
    end
  end

  describe 'B1 · sin ninguna rama' do
    it 'avisa que el motor va a leer 0 ramas' do
      r = validar("[ROL] Sos un agente amable.\n[ESTILO] Breve.")

      expect(codigos(r, :blocking)).to include(:no_routes)
      expect(r[:valid]).to be(false)
    end
  end

  describe 'B3 · directiva suelta en la prosa' do
    # El motor blanquea el complementary_prompt entero cuando encuentra una
    # directiva de búsqueda fuera de las líneas @ruta.
    it 'la marca como bloqueante y explica que blanquea el Entrenamiento entero' do
      source('discourse', 'Foro Kontrolya')

      r = validar(<<~TXT)
        @ruta(soporte #soporte: no puedo entrar): @buscar_foro(Foro Kontrolya)

        [ROL] Sos el agente de soporte. Si no sabés, usá @buscar_articulo.
      TXT

      hallazgo = r[:blocking].find { |f| f[:code] == :loose_directive }
      expect(hallazgo[:message]).to include('borra la prosa entera')
      expect(hallazgo[:wrote]).to eq('@buscar_articulo')
    end

    # El blanqueo alcanza solo a la prosa del camino conversacional. Decirle a
    # alguien que su agente "se queda sin nada" cuando sus ramas siguen andando
    # quema la credibilidad del aviso.
    it 'con ramas declaradas aclara que las ramas siguen funcionando' do
      source('discourse', 'Foro Kontrolya')

      r = validar("@ruta(soporte #soporte: no puedo entrar): @buscar_foro(Foro Kontrolya)\n\n[ROL] Usá @buscar_articulo.")

      expect(r[:blocking].find { |f| f[:code] == :loose_directive }[:message])
        .to include('las ramas en sí siguen funcionando')
    end

    it 'sin ramas dice que el agente se queda sin ninguna instrucción' do
      r = validar('[ROL] Sos el agente. Si no sabés, usá @buscar_articulo.')

      expect(r[:blocking].find { |f| f[:code] == :loose_directive }[:message])
        .to include('se queda sin ninguna')
    end

    it 'no la dispara cuando las directivas viven dentro de las líneas @ruta' do
      source('discourse', 'Foro Kontrolya')

      r = validar("@ruta(soporte #soporte: no puedo entrar): @buscar_foro(Foro Kontrolya)\n\n[ROL] Sos el agente.")

      expect(codigos(r, :blocking)).not_to include(:loose_directive)
    end
  end

  describe 'B4 · fuente que el motor no reconoce' do
    it 'avisa que la rama va a contestar sin consultar nada' do
      r = validar('@ruta(soporte #soporte: no puedo entrar): @buscar_en_google')

      expect(codigos(r, :blocking)).to include(:unknown_source)
    end
  end

  describe 'B5 · fuente nombrada que no existe en la cuenta' do
    # Es la falla más silenciosa de todas: parsea perfecto y no encuentra nunca.
    it 'la marca y lista las fuentes que sí existen' do
      source('discourse', 'Foro Kontrolya')

      r = validar('@ruta(soporte #soporte: no puedo entrar): @buscar_foro(Foro Soporte)')

      hallazgo = r[:blocking].find { |f| f[:code] == :source_not_found }
      expect(hallazgo[:message]).to include('va a buscar y no encontrar nunca')
      expect(hallazgo[:message]).to include('Foro Kontrolya')
    end

    it 'acepta el nombre con otra capitalización, como hace el motor' do
      source('discourse', 'Foro Kontrolya')

      r = validar('@ruta(soporte #soporte: no puedo entrar): @buscar_foro(foro kontrolya)')

      expect(codigos(r, :blocking)).not_to include(:source_not_found)
    end
  end

  describe 'B6 · tipo de caso inexistente' do
    it 'la marca y lista los tipos que sí existen' do
      case_type('Soporte')

      r = validar('@ruta(soporte #soporte: no puedo entrar): - -> @crear_ticket(tipo=Incidencias)')

      hallazgo = r[:blocking].find { |f| f[:code] == :case_type_not_found }
      expect(hallazgo[:message]).to include('Soporte')
      expect(hallazgo[:wrote]).to eq('tipo=Incidencias')
    end

    it 'no la dispara cuando el tipo existe' do
      case_type('Soporte')

      r = validar('@ruta(soporte #soporte: no puedo entrar): - -> @crear_ticket(tipo=Soporte)')

      expect(codigos(r, :blocking)).not_to include(:case_type_not_found)
    end
  end

  describe 'B7 · rama por defecto no declarada' do
    it 'la marca y lista las ramas que sí se declararon' do
      r = validar("@ruta(soporte #soporte: no puedo entrar): -\n@ruta_por_defecto: comercial")

      hallazgo = r[:blocking].find { |f| f[:code] == :default_route_unknown }
      expect(hallazgo[:message]).to include('soporte')
    end
  end

  # ── degradan ────────────────────────────────────────────────────────────────
  describe 'D1 · rama sin descripción' do
    # La descripción es lo único que el clasificador usa para rutear.
    it 'avisa que esa rama casi nunca se va a elegir' do
      r = validar('@ruta(soporte #soporte): -')

      expect(codigos(r, :degrading)).to include(:route_without_description)
      expect(r[:valid]).to be(true)
    end
  end

  describe 'D2 · etiqueta que no existe en la cuenta' do
    it 'avisa que no va a disparar ninguna automatización' do
      create(:label, account: account, title: 'demo')

      r = validar('@ruta(soporte #soporte: no puedo entrar): -')

      hallazgo = r[:degrading].find { |f| f[:code] == :label_not_found }
      expect(hallazgo[:message]).to include('no va a disparar ninguna automatización')
      expect(hallazgo[:wrote]).to eq('#soporte')
    end

    it 'no la dispara cuando la etiqueta existe' do
      create(:label, account: account, title: 'soporte')

      r = validar('@ruta(soporte #soporte: no puedo entrar): -')

      expect(codigos(r, :degrading)).not_to include(:label_not_found)
    end
  end

  describe 'D4 · {{consulta:}} conviviendo con otra cosa' do
    # perform_erp_query manda el Entrenamiento ENTERO interpolado como mensaje:
    # con ramas o prosa, el cliente recibe el Entrenamiento completo.
    it 'avisa cuando hay ramas además de la directiva de ERP' do
      r = validar("@ruta(cobranza #cobro: mi saldo): -\n\nTu saldo es {{consulta:saldo}}")

      expect(codigos(r, :degrading)).to include(:erp_directive_not_isolated)
    end

    it 'no la dispara cuando el Entrenamiento es solo la plantilla del mensaje' do
      r = validar('{{consulta:saldo}}')

      expect(codigos(r, :degrading)).not_to include(:erp_directive_not_isolated)
    end
  end

  describe 'D5 · régimen de escalamiento mixto' do
    # En cuanto UNA rama lleva flecha, las que no la llevan dejan de abrir casos.
    it 'nombra las ramas que se quedaron sin abrir casos' do
      case_type('Soporte')

      r = validar(<<~TXT)
        @ruta(soporte #soporte: no puedo entrar): - -> @crear_ticket(tipo=Soporte)
        @ruta(comercial #comercial: precios, licencias): -
      TXT

      hallazgo = r[:degrading].find { |f| f[:code] == :mixed_escalation_regime }
      expect(hallazgo[:message]).to include('comercial')
    end

    it 'no la dispara cuando ninguna rama lleva flecha' do
      r = validar("@ruta(soporte #soporte: no puedo entrar): -\n@ruta(comercial #comercial: precios): -")

      expect(codigos(r, :degrading)).not_to include(:mixed_escalation_regime)
    end
  end

  describe 'D6 · adjunto en un Entrenamiento con fuente' do
    it 'avisa que el adjunto sale como texto literal' do
      source('discourse', 'Foro Kontrolya')

      r = validar(<<~TXT)
        @ruta(soporte #soporte: no puedo entrar): @buscar_foro(Foro Kontrolya)

        [ROL] Si te piden el catálogo mandá {{catalogo}}.
      TXT

      expect(codigos(r, :degrading)).to include(:attachment_with_source)
    end

    it 'no confunde {{doc:}} ni {{hoja:}} con un adjunto' do
      source('google_sheet', 'Precios 2026')

      r = validar('@ruta(comercial #comercial: precios): {{hoja:Precios 2026}}')

      expect(codigos(r, :degrading)).not_to include(:attachment_with_source)
    end
  end

  describe 'C1 · secciones de la prosa' do
    it 'lista las que faltan sin invalidar nada' do
      r = validar("@ruta(soporte #soporte: no puedo entrar): -\n\n[ROL] Sos el agente.")

      hallazgo = r[:cosmetic].find { |f| f[:code] == :missing_prose_sections }
      expect(hallazgo[:message]).to include('[FIDELIDAD]')
      expect(r[:valid]).to be(true)
    end

    it 'no dice nada cuando no hay prosa con formato: eso no es "faltar secciones"' do
      r = validar('@ruta(soporte #soporte: no puedo entrar): -')

      expect(codigos(r, :cosmetic)).to be_empty
    end
  end

  # ── el caso completo ────────────────────────────────────────────────────────
  describe 'un Entrenamiento correcto' do
    it 'no encuentra nada bloqueante' do
      source('discourse', 'Foro Kontrolya')
      case_type('Soporte')
      create(:label, account: account, title: 'soporte')

      r = validar(<<~TXT)
        @ruta(soporte #soporte: no puedo entrar, error al abrir, el sistema no responde): @buscar_foro(Foro Kontrolya) -> @crear_ticket(tipo=Soporte, prioridad=media)
        @ruta_por_defecto: soporte

        [ROL] Sos el agente de soporte.
        [ALCANCE POR RAMA] En soporte contestás con el foro.
        [FIDELIDAD] No inventes nada que no esté en la fuente.
        [ETIQUETAS] Cerrá con #soporte.
        [ESTILO] Claro y breve.
        [PROHIBIDO] No prometer plazos.
      TXT

      expect(r[:blocking]).to be_empty
      expect(r[:degrading]).to be_empty
      expect(r[:valid]).to be(true)
      expect(r[:routes].size).to eq(1)
    end
  end
end
