# frozen_string_literal: true

# proyecto@asistente_agentes_ia
require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::ValidatorService do
  let(:account) { create(:account) }

  # Los mensajes se traducen (config/locales/tracking_assistant.*.yml) y el idioma
  # sale de la cuenta. Este archivo asegura los textos EN ESPAÑOL, así que fija el
  # idioma en vez de heredar el default del entorno de test — que es `en` y hacía
  # fallar todas las aserciones de texto sin que el comprobador tuviera nada malo.
  # El inglés tiene su propio bloque al final.
  around { |example| I18n.with_locale(:es) { example.run } }

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

    # 24/09/2026: una rama real terminaba en «?)», sin fuente después.
    it 'señala la fuente que falta al final, y cuelga el aviso de la rama' do
      r = validar('@ruta(informacion_general #informacion: ¿cómo trabajan?, ¿qué me pueden decir?)')

      hallazgo = r[:blocking].find { |f| f[:code] == :route_line_unparsed }
      expect(hallazgo[:message]).to include('falta «: fuente»', '«): -»')
      expect(hallazgo[:route]).to eq('informacion_general')
    end

    it 'no repite el genérico "0 ramas" cuando ya explicó línea por línea' do
      r = validar('@ruta(soporte #soporte: no puedo entrar) @buscar_articulo')

      expect(codigos(r, :blocking)).to include(:route_line_unparsed)
      expect(codigos(r, :blocking)).not_to include(:no_routes)
    end
  end

  # 24/09/2026: el motor lee solo «@crear_ticket» y abre el caso con tipo y
  # prioridad por defecto, sin avisar a nadie.
  describe 'B11 · una directiva de la rama sin cerrar' do
    it 'marca el @crear_ticket sin «)» y dice que ignora tipo y prioridad' do
      r = validar('@ruta(info #info: ¿qué hacen?): @buscar_predefinidas -> @crear_ticket(tipo=Soporte, prioridad=media')

      hallazgo = r[:blocking].find { |f| f[:code] == :unclosed_directive }
      expect(hallazgo).to include(route: 'info', wrote: '@crear_ticket(tipo=Soporte, prioridad=media')
      expect(hallazgo[:message]).to include('IGNORA', '«)»')
    end

    it 'marca una fuente sin «}}»' do
      r = validar('@ruta(precios #precios: cuánto cuesta): {{hoja:Precios')

      expect(r[:blocking].find { |f| f[:code] == :unclosed_directive }[:message]).to include('«}}»')
    end

    it 'no marca las que cierran' do
      r = validar('@ruta(info #info: x): {{hoja:Precios}} -> @crear_ticket(tipo=Soporte, prioridad=media)')

      expect(codigos(r, :blocking)).not_to include(:unclosed_directive)
    end
  end

  describe 'B1 · sin ninguna rama' do
    it 'avisa que el motor va a leer 0 ramas' do
      r = validar("[ROL] Sos un agente amable.\n[ESTILO] Breve.")

      expect(codigos(r, :blocking)).to include(:no_routes)
      expect(r[:valid]).to be(false)
    end
  end

  # ── D7 · lo que hasta el 11/09/2026 era B3, bloqueante ──────────────────────
  # Hasta ese día el motor BLANQUEABA el Entrenamiento entero por una directiva
  # suelta, y el aviso impedía guardar. develop lo corrigió: strip_tokens quita
  # solo el token y conserva la prosa. Estos ejemplos cambiaron con el motor — y
  # es la tercera vez en dos días que un mensaje de este módulo quedó afirmando
  # algo que el motor dejó de hacer.
  describe 'D7 · directiva suelta en la prosa' do
    let(:con_directiva_suelta) do
      <<~TXT
        @ruta(soporte #soporte: no puedo entrar): @buscar_foro(Foro Kontrolya)

        [ROL] Sos el agente de soporte. Si no sabés, usá @buscar_articulo.
      TXT
    end

    before { source('discourse', 'Foro Kontrolya') }

    it 'avisa que ahí no se ejecuta, y deja guardar' do
      r = validar(con_directiva_suelta)

      hallazgo = r[:degrading].find { |f| f[:code] == :loose_directive }
      expect(hallazgo[:message]).to include('NO se ejecuta')
      expect(hallazgo[:wrote]).to eq('@buscar_articulo')
      expect(r[:valid]).to be(true)
    end

    # El aviso ya no puede prometer un blanqueo que el motor no hace.
    it 'ya no dice que borra la prosa' do
      mensaje = validar(con_directiva_suelta)[:degrading]
                .find { |f| f[:code] == :loose_directive }[:message]

      expect(mensaje).not_to include('borra la prosa')
      expect(mensaje).not_to include('se queda sin ninguna')
    end

    it 'no impide guardar, a diferencia de antes' do
      expect(codigos(validar(con_directiva_suelta), :blocking)).not_to include(:loose_directive)
    end

    it 'no la dispara cuando las directivas viven dentro de las líneas @ruta' do
      r = validar("@ruta(soporte #soporte: no puedo entrar): @buscar_foro(Foro Kontrolya)\n\n[ROL] Sos el agente.")

      expect(codigos(r, :degrading)).not_to include(:loose_directive)
    end

    # El motor de verdad, no el mensaje: si strip_tokens volviera a blanquear, esto
    # se pone rojo y el aviso hay que subirlo a bloqueante otra vez.
    it 'coincide con lo que hace el motor: conserva la prosa alrededor' do
      limpio = KnowledgeBase::Directives.strip_tokens('Si no sabés, usá @buscar_articulo para responder.')

      expect(limpio).to include('Si no sabés, usá')
      expect(limpio).to include('para responder.')
      expect(limpio).not_to include('@buscar_articulo')
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

  # Salió de una corrida real contra OpenAI: el modelo escribió "- 3e" en vez de
  # "->", RouteMap no partió la línea, y el @crear_ticket quedó atrapado dentro de
  # la fuente. La rama se veía válida —un escalamiento vacío es legal— y el agente
  # que se pidió para abrir tickets no abría ninguno.
  describe 'B8 · una acción atrapada dentro de la fuente' do
    it 'la marca cuando la flecha está mal escrita' do
      r = validar('@ruta(soporte #soporte: no puedo entrar): @buscar_articulo - 3e @crear_ticket(tipo=Soporte)')

      hallazgo = r[:blocking].find { |f| f[:code] == :action_trapped_in_source }
      expect(hallazgo[:message]).to include('le falta la flecha')
      expect(r[:routes].first[:escalation]).to be_nil
    end

    it 'la marca cuando falta la flecha del todo' do
      r = validar('@ruta(soporte #soporte: no puedo entrar): @buscar_articulo @agendar_calendar')

      expect(codigos(r, :blocking)).to include(:action_trapped_in_source)
    end

    it 'no la dispara cuando la flecha está bien' do
      case_type('Soporte')

      r = validar('@ruta(soporte #soporte: no puedo entrar): @buscar_articulo -> @crear_ticket(tipo=Soporte)')

      expect(codigos(r, :blocking)).not_to include(:action_trapped_in_source)
      expect(r[:routes].first[:escalation]).to eq('@crear_ticket(tipo=Soporte)')
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

  describe 'D9 · rama que no consulta nada ni hace nada si no resuelve' do
    it 'avisa en ámbar, colgado de la rama, sin impedir guardar' do
      r = validar('@ruta(saludo #saludo: hola, buenos días): -')

      aviso = r[:degrading].find { |f| f[:code] == :route_does_nothing }
      expect(aviso).to include(route: 'saludo')
      expect(aviso[:message]).to include("'saludo'", 'a propósito')
      expect(r[:valid]).to be(true)
    end

    it 'con una acción después de la flecha sí hace algo' do
      r = validar('@ruta(agendar #agendar: quiero una cita): - -> @agendar_calendar')

      expect(codigos(r, :degrading)).not_to include(:route_does_nothing)
    end

    it 'con una fuente tampoco' do
      r = validar('@ruta(soporte #soporte: no puedo entrar): @buscar_articulo')

      expect(codigos(r, :degrading)).not_to include(:route_does_nothing)
    end
  end

  # Fase C: el Entrenamiento se arma a la vista, con marcas mientras dura la entrevista.
  describe 'B9 · datos por completar' do
    it 'bloquea mientras quede alguna marca, y dice cuáles' do
      r = validar("@ruta(soporte #soporte: no puedo entrar): -\n\n[ESTILO]\n<PENDIENTE: tono>")

      hallazgo = r[:blocking].find { |f| f[:code] == :pending_marker }
      expect(hallazgo[:message]).to include('<PENDIENTE: tono>')
      expect(r[:valid]).to be(false)
    end

    # Sin la línea, la pantalla no puede señalar dónde falta el dato.
    it 'dice en qué línea está la primera marca' do
      r = validar("[ROL]\nSos un asesor.\n\n[ESTILO]\n<PENDIENTE: tono>")

      expect(r[:blocking].find { |f| f[:code] == :pending_marker }[:line]).to eq(5)
    end

    it 'cuenta todas las marcas aunque digan lo mismo' do
      r = validar(<<~T)
        @ruta(uno #uno_x: <PENDIENTE: frases>): -
        @ruta(dos #dos_x: <PENDIENTE: frases>): -
      T

      expect(r[:blocking].find { |f| f[:code] == :pending_marker }[:message]).to include('Faltan 2')
    end

    # Antes cada marca salía disfrazada de otro problema, y peor explicado.
    it 'no disfraza las marcas de fuente desconocida, descripción repetida o tipo inexistente' do
      r = validar(<<~T)
        @ruta(uno #uno_x: <PENDIENTE: frases>): <PENDIENTE: fuente> -> @crear_ticket(tipo=<PENDIENTE: tipo>)
        @ruta(dos #dos_x: <PENDIENTE: frases>): <PENDIENTE: fuente>
      T

      codigos = (r[:blocking] + r[:degrading]).pluck(:code)
      expect(codigos).to include(:pending_marker)
      expect(codigos).not_to include(:unknown_source, :duplicate_route_description, :case_type_not_found)
    end

    it 'reconoce la marca en inglés' do
      expect(codigos(validar("@ruta(uno #uno_x: x): -\n<PENDING: hours>"), :blocking)).to include(:pending_marker)
    end
  end

  describe 'B10 · restos del contrato del Asistente' do
    # Así se entregó el agente #7512: los rótulos de zona y la prosa entre ‹ ›.
    let(:con_restos) do
      <<~T
        ═══ ZONA 1 · líneas de configuración ═══
        @ruta(citas #citado: quiero una cita): -

        ═══ ZONA 2 · la prosa ═══
        [ROL]
        ‹El agente agenda citas médicas.›

        [LIMITES]
        ‹No da diagnósticos.›
      T
    end

    it 'bloquea los rótulos ═══ y dice en qué líneas están' do
      hallazgo = validar(con_restos)[:blocking].find { |f| f[:code] == :contract_label }

      expect(hallazgo[:message]).to include('2 línea(s)').and include('1, 4')
      expect(hallazgo).to include(line: 1, wrote: '═══ ZONA 1 · líneas de configuración ═══')
    end

    it 'bloquea el texto entre ‹ › aparte, porque se corrige distinto' do
      r = validar(con_restos)

      hallazgo = r[:blocking].find { |f| f[:code] == :contract_wrap }
      expect(hallazgo[:message]).to include('6, 9')
      expect(r[:valid]).to be(false)
    end

    # Hay Entrenamientos reales con renglones de === como separador.
    it 'no confunde una línea de decoración con un rótulo' do
      r = validar("@ruta(citas #citado: quiero una cita): -\n\n=====================\n═══════════\n[ROL]\nAgenda citas.")

      expect(codigos(r, :blocking)).not_to include(:contract_label, :contract_wrap)
    end

    it 'sin restos no dice nada' do
      r = validar("@ruta(citas #citado: quiero una cita): -\n\n[ROL]\nAgenda «citas» médicas.")

      expect(codigos(r, :blocking)).not_to include(:contract_label, :contract_wrap)
    end
  end

  describe 'D8 · dos ramas que describen lo mismo' do
    # Salió de una corrida real del Asistente: escribió "quiero hablar con un asesor"
    # como descripción de gestiones_comerciales Y de pase_a_humano. Parsea perfecto,
    # y una de las dos ramas no se ejecuta nunca.
    it 'avisa cuando dos ramas comparten la descripción' do
      r = validar(<<~T)
        @ruta(comercial #comercial: quiero hablar con un asesor): -
        @ruta(humano #humano: quiero hablar con un asesor): -
      T

      expect(codigos(r, :degrading)).to include(:duplicate_route_description)
      expect(r[:valid]).to be(true)
    end

    # Se compara el contenido, no los caracteres: tildes, mayúsculas y puntuación no
    # cambian a qué rama manda el clasificador.
    it 'las ve iguales aunque cambien tildes, mayúsculas o puntuación' do
      r = validar(<<~T)
        @ruta(comercial #comercial: ¿Cuánto cuesta la licencia?): -
        @ruta(precios #precios: cuanto cuesta la licencia): -
      T

      expect(codigos(r, :degrading)).to include(:duplicate_route_description)
    end

    it 'no avisa cuando cada rama describe algo distinto' do
      r = validar(<<~T)
        @ruta(soporte #soporte: no puedo entrar al sistema): -
        @ruta(precios #precios: cuanto cuesta la licencia): -
      T

      expect(codigos(r, :degrading)).not_to include(:duplicate_route_description)
    end

    # Las ramas sin descripción ya las marca D1: si además se agruparan entre ellas,
    # el mismo defecto saldría dos veces con dos nombres distintos.
    it 'no agrupa entre sí a las ramas que no tienen descripción' do
      r = validar(<<~T)
        @ruta(uno #uno_x): -
        @ruta(dos #dos_x): -
      T

      expect(codigos(r, :degrading)).not_to include(:duplicate_route_description)
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

  # Con grupo el umbral sube de 0.20 a 0.45: la búsqueda se vuelve mucho más
  # exigente. Sobre dos o tres respuestas, la rama casi nunca encuentra nada.
  # Salió de una corrida real: el asistente le puso el grupo DATOS —dos respuestas,
  # de datos fiscales y bancarios— a una rama de actualizaciones de versión.
  describe 'D7 · grupo de predefinidas con corpus mínimo' do
    it 'avisa cuando el grupo tiene muy pocas respuestas' do
      create(:canned_response, account: account, short_code: 'DATOS FISCALES')
      create(:canned_response, account: account, short_code: 'DATOS BANCARIOS')

      r = validar('@ruta(actualizaciones #demo: instalar la nueva version): @buscar_predefinidas(DATOS)')

      hallazgo = r[:degrading].find { |f| f[:code] == :canned_group_too_small }
      expect(hallazgo[:message]).to include('2 respuestas predefinidas', '0.45')
      expect(r[:valid]).to be(true)
    end

    it 'no avisa cuando el grupo tiene contenido suficiente' do
      5.times { |i| create(:canned_response, account: account, short_code: "GESTION #{i}") }

      r = validar('@ruta(gestion #demo: alta de usuario): @buscar_predefinidas(GESTION)')

      expect(codigos(r, :degrading)).not_to include(:canned_group_too_small)
    end

    # Sin grupo el umbral es 0.20 y busca sobre todo el corpus: no aplica.
    it 'no avisa cuando la rama busca sin grupo' do
      create(:canned_response, account: account, short_code: 'DATOS FISCALES')

      r = validar('@ruta(soporte #demo: no puedo entrar): @buscar_predefinidas')

      expect(codigos(r, :degrading)).not_to include(:canned_group_too_small)
    end

    # Un grupo negado no estrecha el corpus: lo amplía.
    it 'no avisa con un grupo negado' do
      create(:canned_response, account: account, short_code: 'DATOS FISCALES')

      r = validar('@ruta(soporte #demo: no puedo entrar): @buscar_predefinidas(!DATOS)')

      expect(codigos(r, :degrading)).not_to include(:canned_group_too_small)
    end

    it 'no avisa cuando la rama no usa predefinidas' do
      source('article', 'Centro de Ayuda')

      r = validar('@ruta(soporte #demo: no puedo entrar): @buscar_articulo')

      expect(codigos(r, :degrading)).not_to include(:canned_group_too_small)
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

  # proyecto@erp_productos — con la F2, el motor ya no manda el Entrenamiento cuando la
  # consulta pide "?" (el agente redacta) ni cuando es la fuente de una ruta.
  describe 'B9, B10 y D4 · {{consulta:}} con "?" (erp_productos)' do
    let(:connection) do
      ExternalDbConnection.create!(account: account, name: 'SAE', engine: :firebird, erp_type: :sae, host: 'erp.test',
                                   port: 3050, database: 'db')
    end

    before do
      connection.external_db_queries.create!(account: account, name: 'buscar_productos',
                                             sql_template: 'SELECT 1 FROM INVE01',
                                             params_schema: ExternalDb::QueryLibrary::PRODUCT_PARAMS)
    end

    it 'con "?" o como fuente de una ruta, puede convivir con otra cosa' do
      con_pregunta = validar("Eres el vendedor.\n{{consulta:sae/buscar_productos(texto=?, precio_max=?)}}")
      de_ruta = validar("@ruta(catalogo #productos: precios, modelos): {{consulta:sae/buscar_productos}}\nEres el vendedor.")

      expect(codigos(con_pregunta, :degrading)).not_to include(:erp_directive_not_isolated)
      expect(codigos(de_ruta, :degrading)).not_to include(:erp_directive_not_isolated)
      expect(codigos(con_pregunta, :blocking)).not_to include(:consulta_not_found, :consulta_unknown_param)
    end

    it 'bloquea una consulta que no existe en la conexión' do
      r = validar('{{consulta:sae/buscar_producto(texto=?)}}')

      expect(codigos(r, :blocking)).to include(:consulta_not_found)
    end

    it 'bloquea un parámetro que la consulta no tiene y dice cuáles sí' do
      r = validar('{{consulta:sae/buscar_productos(texto=?, pecio_max=?)}}')
      hallazgo = r[:blocking].find { |f| f[:code] == :consulta_unknown_param }

      expect(hallazgo[:message]).to include('pecio_max', 'precio_max')
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

  # ── D7 · @agendar_calendar sin calendario ───────────────────────────────────
  # El motor solo agenda si el agente tiene calendarios asignados. Escrita sin
  # ninguno en la cuenta, la directiva parsea, el comprobador la veía bien, y el
  # turno pasaba de largo sin agendar y sin avisar.
  describe 'D7 · @agendar_calendar sin ningún calendario en la cuenta' do
    let(:entrenamiento) { '@ruta(agenda #agenda: quiero una cita): - -> @agendar_calendar' }

    it 'avisa que no va a agendar nada' do
      hallazgo = validar(entrenamiento)[:degrading].find { |f| f[:code] == :calendar_not_configured }

      expect(hallazgo[:message]).to include('no tiene ningún calendario')
      expect(hallazgo[:wrote]).to eq('@agendar_calendar')
    end

    # ⚠ Falló 2 veces de ~15 en la suite combinada (15/09/2026) y nunca sola; no se pudo
    # reproducir. La primera expectativa separa las dos causas posibles la próxima vez:
    # si falla ESA, la integración no quedó visible para la consulta (base compartida
    # con desarrollo, conexión distinta); si falla la segunda, el comprobador la ignoró.
    it 'no avisa cuando la cuenta sí tiene un calendario conectado' do
      UserCalendarIntegration.create!(account: account, user: create(:user, account: account),
                                      google_email: 'agenda@empresa.com', tokens: {})

      expect(UserCalendarIntegration.exists?(account_id: account.id))
        .to be(true), "la integración recién creada no es visible (conexión: #{ActiveRecord::Base.connection.object_id})"
      expect(validar(entrenamiento)[:degrading].pluck(:code)).not_to include(:calendar_not_configured)
    end

    # Avisa, no bloquea: el agente sigue contestando y sigue abriendo casos, y el
    # arreglo está en los ajustes de Chatwoot, no en el Entrenamiento.
    it 'no impide guardar' do
      expect(validar(entrenamiento)[:valid]).to be(true)
    end
  end
end
