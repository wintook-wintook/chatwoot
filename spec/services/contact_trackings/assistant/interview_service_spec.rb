# frozen_string_literal: true

# proyecto@asistente_agentes_ia
require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::InterviewService do
  # El prompt de corrección se traduce con la cuenta (config/locales/tracking_assistant.*).
  # Este archivo asegura los textos en español, así que fija el idioma en vez de heredar
  # el default del entorno de test, que es `en`.
  around { |example| I18n.with_locale(:es) { example.run } }

  let(:account) { create(:account) }
  let(:url) { described_class::API_URL }
  let(:entrenamiento_ok) do
    '@ruta(soporte #soporte1: no puedo entrar, me da error): @buscar_articulo ' \
      "-> @crear_ticket(tipo=Soporte, prioridad=media)\n@ruta_por_defecto: soporte"
  end
  # Le falta el ":" tras el paréntesis: el motor lee 0 ramas. Es el fallo medido.
  let(:entrenamiento_roto) { '@ruta(soporte #soporte1: no puedo entrar) @buscar_articulo' }

  before do
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled',
                               settings: { 'api_key' => 'sk-test' })
    KnowledgeSource.create!(account: account, source_type: 'article', name: 'Centro de Ayuda', status: 'active')
    CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6')
    create(:label, account: account, title: 'soporte1')
  end

  # Una respuesta de OpenAI con el JSON que exige el contrato de salida. `modo` es
  # obligatorio cuando hay Entrenamiento: es la respuesta a la pregunta que el
  # asistente no puede saltearse.
  # :auto = "el que corresponda"; nil explícito = "no lo declaró", que es el caso
  # que la guarda tiene que rechazar.
  def openai_reply(mensaje:, entrenamiento: nil, modo: :auto, propuesta: nil, **extra)
    modo = (entrenamiento ? 'responde' : nil) if modo == :auto
    cuerpo = { mensaje: mensaje, modo: modo, entrenamiento: entrenamiento, propuesta: propuesta, **extra }
    { choices: [{ message: { content: cuerpo.to_json } }] }.to_json
  end

  def stub_openai(*bodies)
    responses = bodies.map { |body| { status: 200, body: body, headers: { 'Content-Type' => 'application/json' } } }
    stub_request(:post, url).to_return(responses)
  end

  def entrevistar(texto = 'quiero un agente de soporte')
    described_class.new(account, messages: [{ 'role' => 'user', 'content' => texto }]).call
  end

  describe 'mientras entrevista' do
    it 'devuelve el mensaje sin borrador cuando el modelo todavía pregunta' do
      stub_openai(openai_reply(mensaje: '¿Qué temas atiende?'))

      resultado = entrevistar

      expect(resultado.reply).to eq('¿Qué temas atiende?')
      expect(resultado.draft).to be_nil
      expect(resultado.repairs).to eq(0)
    end
  end

  describe 'cuando entrega un Entrenamiento' do
    it 'lo devuelve ya comprobado' do
      stub_openai(openai_reply(mensaje: 'Listo', entrenamiento: entrenamiento_ok))

      resultado = entrevistar

      expect(resultado.draft).to eq(entrenamiento_ok)
      expect(resultado.validation[:valid]).to be(true)
      expect(resultado.validation[:routes].size).to eq(1)
      expect(resultado.repairs).to eq(0)
    end
  end

  # ── fase A: editar, no reescribir ───────────────────────────────────────────
  # Hasta el 15/09/2026 el modelo nunca veía el Entrenamiento que estaba en pantalla:
  # "agregá una rama" se resolvía reescribiendo de memoria.
  describe 'editando un Entrenamiento que ya existe' do
    let(:actual) do
      <<~T.strip
        @ruta(soporte #soporte1: no puedo entrar): @buscar_articulo -> @crear_ticket(tipo=Soporte, prioridad=media)
        @ruta_por_defecto: soporte

        [QUIEN ERES]
        Sos el asistente de Kontrolya.

        [NO SIMULAR]
        Nunca digas que ya quedó agendado.

        [ESTILO]
        Breve.
      T
    end
    let(:con_emojis) { actual.sub('Breve.', "Breve.\nSin emojis.") }

    def editar(texto = 'sin emojis', draft: actual)
      described_class.new(account, messages: [{ 'role' => 'user', 'content' => texto }], current_draft: draft).call
    end

    it 'le muestra al modelo el Entrenamiento que está en pantalla' do
      stub_openai(openai_reply(mensaje: '¿Qué querés cambiar?'))

      editar

      pedido = a_request(:post, url).with do |req|
        sistema = JSON.parse(req.body)['messages'].first['content']
        sistema.include?('ENTRENAMIENTO ACTUAL') && sistema.include?('Nunca digas que ya quedó agendado.')
      end
      expect(pedido).to have_been_made
    end

    it 'no le muestra nada de eso al crear' do
      stub_openai(openai_reply(mensaje: '¿Qué temas atiende?'))

      entrevistar

      expect(a_request(:post, url).with { |req| req.body.include?('ENTRENAMIENTO ACTUAL') }).not_to have_been_made
    end

    # El comportamiento ya está escrito en lo que había: preguntar "¿contesta o
    # deriva?" para agregar una regla de estilo sería hacer perder un turno.
    it 'no exige el modo para aceptar una edición' do
      stub_openai(openai_reply(mensaje: 'Listo', entrenamiento: con_emojis, modo: nil, toca: ['[ESTILO]']))

      resultado = editar

      expect(resultado.draft).to eq(con_emojis)
      expect(a_request(:post, url)).to have_been_made.once
    end

    it 'devuelve lo que cambió de verdad junto al resumen del modelo' do
      stub_openai(openai_reply(mensaje: 'Listo', entrenamiento: con_emojis,
                               toca: ['[ESTILO]'], cambios: ['~ [ESTILO]: sin emojis']))

      cambios = editar.changes

      expect(cambios[:summary]).to eq(['~ [ESTILO]: sin emojis'])
      expect(cambios[:touched]).to eq([{ key: '[ESTILO]', kind: :changed, declared: true }])
    end

    # Medido sobre el v6.11: declaró la rama nueva y no la línea que sumó en
    # [ETIQUETAS]. No es destructivo, así que no vale otra llamada; pero se marca.
    it 'marca lo que cambió sin declararlo, sin gastar otra llamada si no es destructivo' do
      stub_openai(openai_reply(mensaje: 'Listo', entrenamiento: con_emojis, toca: []))

      resultado = editar

      expect(resultado.changes[:touched]).to eq([{ key: '[ESTILO]', kind: :changed, declared: false }])
      expect(a_request(:post, url)).to have_been_made.once
    end

    it 'le devuelve una sección borrada que nadie pidió borrar, y se queda con lo corregido' do
      sin_seccion = con_emojis.sub("[NO SIMULAR]\nNunca digas que ya quedó agendado.\n\n", '')
      stub_openai(openai_reply(mensaje: 'Listo', entrenamiento: sin_seccion, toca: ['[ESTILO]']),
                  openai_reply(mensaje: 'Restaurada', entrenamiento: con_emojis, toca: ['[ESTILO]']))

      resultado = editar

      expect(resultado.draft).to eq(con_emojis)
      correccion = a_request(:post, url).with do |req|
        JSON.parse(req.body)['messages'].last['content'].include?('quitaste [NO SIMULAR]')
      end
      expect(correccion).to have_been_made
    end

    # Una modificación fallida nunca le cuesta a nadie el Entrenamiento que funcionaba.
    it 'conserva lo que había si lo nuevo no ejecuta, y devuelve lo propuesto aparte' do
      roto = actual.sub('@ruta(soporte #soporte1: no puedo entrar):', '@ruta(soporte #soporte1: no puedo entrar)')
      stub_openai(*Array.new(described_class::MAX_REPAIRS + 1) do
        openai_reply(mensaje: 'Ahí va', entrenamiento: roto, toca: ['@ruta(soporte)'])
      end)

      resultado = editar

      expect(resultado.draft).to eq(actual)
      expect(resultado.validation[:valid]).to be(true)
      expect(resultado.rejected_draft).to eq(roto)
      expect(resultado.rejected_validation[:valid]).to be(false)
    end

    # Si lo que había tampoco ejecutaba —"Arreglarlo acá"—, no hay nada mejor que
    # conservar: se entrega lo nuevo con sus errores a la vista.
    it 'entrega lo nuevo aunque no ejecute si lo que había tampoco ejecutaba' do
      roto = '@ruta(soporte #soporte1: no puedo entrar) @buscar_articulo'
      stub_openai(*Array.new(described_class::MAX_REPAIRS + 1) do
        openai_reply(mensaje: 'Ahí va', entrenamiento: "#{roto}\n[ESTILO]\nBreve.", toca: ['[ESTILO]'])
      end)

      resultado = editar(draft: roto)

      expect(resultado.draft).to include('[ESTILO]')
      expect(resultado.rejected_draft).to be_nil
    end

    # Un cruce que el Entrenamiento ya traía se muestra, pero no justifica reescribir
    # una rama que la persona no pidió tocar.
    it 'no corrige el ruteo de una rama que no se tocó' do
      dos = actual.sub('@ruta_por_defecto', "@ruta(precios #soporte1: cuanto cuesta): @buscar_articulo\n@ruta_por_defecto")
      cruce = ContactTrackings::Assistant::RouteSelfCheck::Mismatch.new(route: 'soporte', probe: 'no puedo entrar',
                                                                        chosen: 'precios')
      allow(ContactTrackings::Assistant::RouteSelfCheck).to receive(:new)
        .and_return(instance_double(ContactTrackings::Assistant::RouteSelfCheck, call: [cruce]))
      stub_openai(openai_reply(mensaje: 'Listo', entrenamiento: dos.sub('Breve.', 'Corto.'), toca: ['[ESTILO]']))

      resultado = editar(draft: dos)

      expect(a_request(:post, url)).to have_been_made.once
      expect(resultado.validation[:degrading].pluck(:code)).to include(:route_not_self_chosen)
    end

    # Pasado el presupuesto del turno no se abre otra vuelta: el proxy cortaría y la
    # persona vería un error aunque el Entrenamiento hubiera salido.
    it 'no abre vueltas de corrección pasado el presupuesto de tiempo' do
      stub_const("#{described_class}::TURN_BUDGET_SECONDS", 0)
      sin_seccion = actual.sub("[NO SIMULAR]\nNunca digas que ya quedó agendado.\n\n", '')
      stub_openai(openai_reply(mensaje: 'Listo', entrenamiento: sin_seccion, toca: []))

      resultado = editar

      expect(a_request(:post, url)).to have_been_made.once
      expect(resultado.changes[:touched]).to include(key: '[NO SIMULAR]', kind: :removed, declared: false)
    end
  end

  # ── el segundo bucle ────────────────────────────────────────────────────────
  # El comprobador dice si el Entrenamiento se EJECUTA; esto dice si RUTEA. Las
  # respuestas del clasificador se fijan acá (RouteSelfCheck tiene su propio spec):
  # lo que se prueba es qué hace la entrevista con un cruce.
  describe 'el bucle de ruteo' do
    let(:dos_ramas) do
      "@ruta(soporte #soporte1: no puedo entrar): @buscar_articulo\n" \
        '@ruta(comercial #soporte1: quiero un asesor): @buscar_articulo'
    end

    def autoprueba_devuelve(*tandas)
      restantes = tandas.dup
      allow(ContactTrackings::Assistant::RouteSelfCheck).to receive(:new) do
        instance_double(ContactTrackings::Assistant::RouteSelfCheck, call: restantes.shift || [])
      end
    end

    def cruce(route:, probe:, chosen:)
      ContactTrackings::Assistant::RouteSelfCheck::Mismatch.new(route: route, probe: probe, chosen: chosen)
    end

    it 'le devuelve el cruce y se queda con lo corregido' do
      autoprueba_devuelve([cruce(route: 'soporte', probe: 'no puedo entrar', chosen: 'comercial')], [])
      stub_openai(openai_reply(mensaje: 'Ahí va', entrenamiento: dos_ramas),
                  openai_reply(mensaje: 'Separé las descripciones', entrenamiento: entrenamiento_ok))

      resultado = entrevistar

      expect(resultado.draft).to eq(entrenamiento_ok)
      expect(resultado.route_mismatches).to be_empty
      # No es una corrección del comprobador: el Entrenamiento anterior ya era válido.
      expect(resultado.repairs).to eq(0)
    end

    it 'le nombra la rama, la frase y la que salió elegida' do
      autoprueba_devuelve([cruce(route: 'soporte', probe: 'no puedo entrar', chosen: 'comercial')], [])
      stub_openai(openai_reply(mensaje: 'Ahí va', entrenamiento: dos_ramas),
                  openai_reply(mensaje: 'Corregido', entrenamiento: entrenamiento_ok))

      entrevistar

      pedido = a_request(:post, url).with do |req|
        texto = JSON.parse(req.body)['messages'].last['content']
        texto.include?('"soporte"') && texto.include?('no puedo entrar') && texto.include?('"comercial"')
      end
      expect(pedido).to have_been_made
    end

    # Una sola vuelta: si con el cruce señalado de frente no lo arregla, una segunda
    # tampoco, y cada vuelta cuesta una clasificación por rama. Se entrega con el
    # aviso a la vista en vez de seguir gastando.
    it 'entrega con el cruce puesto cuando el modelo no lo arregla' do
      cruces = [cruce(route: 'soporte', probe: 'no puedo entrar', chosen: 'comercial')]
      autoprueba_devuelve(cruces, cruces, cruces)
      stub_openai(openai_reply(mensaje: 'Ahí va', entrenamiento: dos_ramas),
                  openai_reply(mensaje: 'Igual', entrenamiento: dos_ramas))

      resultado = entrevistar

      expect(resultado.route_mismatches.map(&:route)).to eq(['soporte'])
      expect(resultado.validation[:valid]).to be(true)
    end

    # Un aviso que vive solo en el log no existe: el cruce que sobrevive sale por el
    # mismo lugar que los hallazgos del comprobador, que es lo que la pantalla mira.
    it 'deja el cruce que sobrevive como hallazgo degradante' do
      cruces = [cruce(route: 'soporte', probe: 'no puedo entrar', chosen: 'comercial')]
      autoprueba_devuelve(cruces, cruces, cruces)
      stub_openai(openai_reply(mensaje: 'Ahí va', entrenamiento: dos_ramas),
                  openai_reply(mensaje: 'Igual', entrenamiento: dos_ramas))

      resultado = entrevistar

      expect(resultado.validation[:degrading].pluck(:code)).to include(:route_not_self_chosen)
      expect(resultado.validation[:degrading].find { |f| f[:code] == :route_not_self_chosen }[:message])
        .to include('soporte', 'no puedo entrar', 'comercial')
    end

    # Un texto con hallazgos bloqueantes no llega a clasificar nada: probar el ruteo
    # ahí es pagar llamadas para que el clasificador lea 0 ramas.
    it 'no prueba el ruteo de un Entrenamiento que no ejecuta' do
      allow(ContactTrackings::Assistant::RouteSelfCheck).to receive(:new)
      stub_openai(*Array.new(4) { openai_reply(mensaje: 'Ahí va', entrenamiento: entrenamiento_roto) })

      entrevistar

      expect(ContactTrackings::Assistant::RouteSelfCheck).not_to have_received(:new)
    end

    # Que no se pueda probar el ruteo no debe costarle el Entrenamiento a nadie.
    it 'entrega lo que ya pasó el comprobador si la prueba se cae' do
      allow(ContactTrackings::Assistant::RouteSelfCheck).to receive(:new).and_raise(StandardError, 'sin red')
      stub_openai(openai_reply(mensaje: 'Listo', entrenamiento: dos_ramas))

      resultado = entrevistar

      expect(resultado.draft).to eq(dos_ramas)
      expect(resultado.route_mismatches).to be_empty
    end
  end

  # El bucle es lo que distingue esto de "pedirle un prompt a una IA": el auditor no
  # es otro modelo opinando, es el parser de producción.
  describe 'el bucle de corrección' do
    it 'le devuelve el diagnóstico y se queda con lo corregido' do
      stub_openai(openai_reply(mensaje: 'Ahí va', entrenamiento: entrenamiento_roto),
                  openai_reply(mensaje: 'Corregido', entrenamiento: entrenamiento_ok))

      resultado = entrevistar

      expect(resultado.repairs).to eq(1)
      expect(resultado.draft).to eq(entrenamiento_ok)
      expect(resultado.validation[:valid]).to be(true)
    end

    it 'le pasa el mensaje del comprobador textual, con el carácter que falta' do
      stub_openai(openai_reply(mensaje: 'Ahí va', entrenamiento: entrenamiento_roto),
                  openai_reply(mensaje: 'Corregido', entrenamiento: entrenamiento_ok))

      entrevistar

      pedido = a_request(:post, url).with { |req| req.body.include?('falta el \":\" inmediatamente después') }
      expect(pedido).to have_been_made.at_least_once
    end

    # Sin tope, un contrato mal escrito quema tokens en círculo.
    it 'se rinde tras MAX_REPAIRS y devuelve el borrador con sus errores' do
      roto = openai_reply(mensaje: 'Ahí va', entrenamiento: entrenamiento_roto)
      stub_openai(roto, roto, roto, roto)

      resultado = entrevistar

      expect(resultado.repairs).to eq(described_class::MAX_REPAIRS)
      expect(resultado.validation[:valid]).to be(false)
      expect(resultado.draft).to eq(entrenamiento_roto)
    end

    it 'corta si el modelo deja de devolver un Entrenamiento' do
      stub_openai(openai_reply(mensaje: 'Ahí va', entrenamiento: entrenamiento_roto),
                  openai_reply(mensaje: 'No sé cómo arreglarlo'))

      resultado = entrevistar

      expect(resultado.repairs).to eq(1)
      expect(resultado.draft).to eq(entrenamiento_roto)
    end
  end

  describe 'el prompt que se manda' do
    before { stub_openai(openai_reply(mensaje: 'ok')) }

    it 'lleva el contrato del motor y el inventario real de la cuenta' do
      entrevistar

      expect(a_request(:post, url).with { |req| req.body.include?('ZONA 1') && req.body.include?('Centro de Ayuda') })
        .to have_been_made
    end

    # El asistente es de cuenta y no tiene inbox: sin el piso de EngineConfig caería
    # al modelo chico, que ya se midió que no cumple las reglas de un prompt largo.
    it 'usa el modelo del piso, no el de por defecto' do
      entrevistar

      expect(a_request(:post, url).with { |req| JSON.parse(req.body)['model'] == 'gpt-4o' }).to have_been_made
    end

    it 'exige salida JSON, que es lo que hace determinista al bucle' do
      entrevistar

      expect(a_request(:post, url).with { |req| JSON.parse(req.body).dig('response_format', 'type') == 'json_object' })
        .to have_been_made
    end
  end

  describe 'cuando algo falla' do
    it 'avisa que la cuenta no tiene integración de OpenAI' do
      account.hooks.find_by(app_id: 'openai').update!(status: 'disabled')

      expect(entrevistar.error).to eq(:no_api_key)
    end

    it 'no revienta si OpenAI responde un error' do
      stub_request(:post, url).to_return(status: 500, body: 'boom')

      expect(entrevistar.error).to eq(:unavailable)
    end

    it 'no revienta si la respuesta no es el JSON esperado' do
      stub_request(:post, url).to_return(
        status: 200, body: { choices: [{ message: { content: 'esto no es json' } }] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

      expect(entrevistar.error).to eq(:unavailable)
    end
  end

  # El botón "generar" de la ficha del Agente IA no tiene conversación donde
  # preguntar: si el asistente devolviera una pregunta, nadie podría contestarla.
  describe 'modo de una sola pasada' do
    def de_una(texto = 'un agente de soporte')
      described_class.new(account, messages: [{ 'role' => 'user', 'content' => texto }], one_shot: true).call
    end

    it 'le prohíbe entrevistar y le exige entregar el Entrenamiento' do
      stub_openai(openai_reply(mensaje: 'Listo', entrenamiento: entrenamiento_ok))

      de_una

      pedido = a_request(:post, url).with do |req|
        system = JSON.parse(req.body)['messages'].first['content']
        system.include?('NO entrevistes') && system.include?('<PENDIENTE:')
      end
      expect(pedido).to have_been_made
    end

    it 'devuelve el Entrenamiento ya comprobado' do
      stub_openai(openai_reply(mensaje: 'Listo', entrenamiento: entrenamiento_ok))

      resultado = de_una

      expect(resultado.draft).to eq(entrenamiento_ok)
      expect(resultado.validation[:valid]).to be(true)
    end

    # El bucle de corrección vale igual acá: es lo que separa este botón del que
    # había antes, que producía prosa que el motor no ejecutaba.
    it 'corrige solo lo que el comprobador rechaza' do
      stub_openai(openai_reply(mensaje: 'Ahí va', entrenamiento: entrenamiento_roto),
                  openai_reply(mensaje: 'Corregido', entrenamiento: entrenamiento_ok))

      resultado = de_una

      expect(resultado.repairs).to eq(1)
      expect(resultado.validation[:valid]).to be(true)
    end

    it 'no manda las instrucciones de entrevista' do
      stub_openai(openai_reply(mensaje: 'Listo', entrenamiento: entrenamiento_ok))

      de_una

      pedido = a_request(:post, url).with do |req|
        JSON.parse(req.body)['messages'].first['content'].exclude?('Máximo')
      end
      expect(pedido).to have_been_made
    end
  end

  # "Contesta primero" y "solo recauda datos" son dos agentes distintos, y la
  # diferencia no se deduce del pedido: "un agente que junte información para abrir
  # un ticket" se lee de las dos maneras. Elegir por la persona le cambia el
  # comportamiento al agente sin que nadie se entere — pasó al probarlo en pantalla.
  describe 'la pregunta que no se puede saltear' do
    it 'rechaza un Entrenamiento entregado sin declarar el modo' do
      stub_openai(openai_reply(mensaje: 'Ahí va', entrenamiento: entrenamiento_ok, modo: nil),
                  openai_reply(mensaje: '¿Contesta primero o solo deriva?'))

      resultado = entrevistar

      expect(resultado.draft).to be_nil
      expect(resultado.reply).to include('Contesta primero')
    end

    it 'le devuelve al mismo hilo la pregunta que le faltó' do
      stub_openai(openai_reply(mensaje: 'Ahí va', entrenamiento: entrenamiento_ok, modo: nil),
                  openai_reply(mensaje: '¿Contesta o deriva?'))

      entrevistar

      pedido = a_request(:post, url).with { |req| req.body.include?('sin preguntar si el agente CONTESTA') }
      expect(pedido).to have_been_made
    end

    it 'acepta el Entrenamiento cuando el modo viene declarado' do
      stub_openai(openai_reply(mensaje: 'Listo', entrenamiento: entrenamiento_ok, modo: 'deriva'))

      resultado = entrevistar

      expect(resultado.draft).to eq(entrenamiento_ok)
      expect(a_request(:post, url)).to have_been_made.once
    end

    it 'rechaza un modo que no es ninguno de los dos' do
      stub_openai(openai_reply(mensaje: 'Ahí va', entrenamiento: entrenamiento_ok, modo: 'lo que sea'),
                  openai_reply(mensaje: '¿Contesta o deriva?'))

      expect(entrevistar.draft).to be_nil
    end

    # Si vuelve a entregar tras el aviso, se sigue como siempre: el comprobador
    # manda igual.
    it 'sigue con el bucle normal si tras el aviso entrega bien' do
      stub_openai(openai_reply(mensaje: 'Ahí va', entrenamiento: entrenamiento_ok, modo: nil),
                  openai_reply(mensaje: 'Corregido', entrenamiento: entrenamiento_ok, modo: 'responde'))

      expect(entrevistar.draft).to eq(entrenamiento_ok)
    end
  end

  # El asistente acaba de entrevistar sobre qué hace el agente: pedir después que
  # se reescriba el nombre y el objetivo es pedir un resumen de lo que se acaba de
  # decir. Y `objective` es obligatorio, así que el campo vacío es un muro.
  describe 'los datos del agente que propone' do
    let(:propuesta) do
      { nombre: 'Soporte Kontrolya', objetivo: 'Resolver dudas y abrir casos',
        contexto: 'Atendemos de 9 a 18' }
    end

    it 'los devuelve junto al Entrenamiento' do
      stub_openai(openai_reply(mensaje: 'Listo', entrenamiento: entrenamiento_ok, propuesta: propuesta))

      expect(entrevistar.proposal).to eq(
        name: 'Soporte Kontrolya', objective: 'Resolver dudas y abrir casos',
        ai_context: 'Atendemos de 9 a 18'
      )
    end

    # El contexto entra al prompt como "BASE DE CONOCIMIENTO" y el agente lo cita
    # como cierto. Vacío es una respuesta válida; inventarlo, no.
    it 'acepta un contexto vacío sin rellenarlo' do
      stub_openai(openai_reply(mensaje: 'Listo', entrenamiento: entrenamiento_ok,
                               propuesta: propuesta.merge(contexto: '')))

      expect(entrevistar.proposal[:ai_context]).to eq('')
    end

    it 'no revienta si el modelo no manda propuesta' do
      stub_openai(openai_reply(mensaje: 'Listo', entrenamiento: entrenamiento_ok))

      expect(entrevistar.proposal).to be_nil
    end

    it 'no propone nada mientras todavía entrevista' do
      stub_openai(openai_reply(mensaje: '¿Qué temas atiende?'))

      expect(entrevistar.proposal).to be_nil
    end

    it 'le prohíbe al modelo inventar el contexto' do
      stub_openai(openai_reply(mensaje: 'ok'))

      entrevistar

      pedido = a_request(:post, url).with do |req|
        JSON.parse(req.body)['messages'].first['content'].include?('NO inventes nada acá')
      end
      expect(pedido).to have_been_made
    end
  end
end
