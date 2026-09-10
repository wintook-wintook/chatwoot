# frozen_string_literal: true

# proyecto@asistente_agentes_ia
require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::InterviewService do
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
  def openai_reply(mensaje:, entrenamiento: nil, modo: :auto, propuesta: nil)
    modo = (entrenamiento ? 'responde' : nil) if modo == :auto
    cuerpo = { mensaje: mensaje, modo: modo, entrenamiento: entrenamiento, propuesta: propuesta }
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
