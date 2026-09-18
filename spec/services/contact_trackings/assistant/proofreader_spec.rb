# frozen_string_literal: true

# proyecto@asistente_agentes_ia
require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::Proofreader do
  let(:account) { create(:account) }

  before do
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' })
  end

  def modelo_devuelve(cuerpo)
    stub_request(:post, ContactTrackings::Assistant::OpenaiChat::API_URL).to_return(
      status: 200, headers: { 'Content-Type' => 'application/json' },
      body: { choices: [{ message: { content: cuerpo.to_json } }] }.to_json
    )
  end

  def corregir(texto, kind: 'objective')
    described_class.new(account, text: texto, kind: kind).call
  end

  # Lo que se le mandó al modelo, para poder afirmar qué dice la instrucción.
  def instruccion_enviada
    cuerpo = nil
    WebMock::RequestRegistry.instance.requested_signatures.each { |firma, _| cuerpo = firma.body }
    cuerpo.to_s
  end

  it 'devuelve el texto corregido, qué cambió y el original' do
    modelo_devuelve(texto: 'Atender consultas de licencias y facturación.',
                    cambios: ['acentos', 'punto final'])

    resultado = corregir('atender consultas de licencias y facturacion')

    expect(resultado).to eq(
      text: 'Atender consultas de licencias y facturación.',
      notes: ['acentos', 'punto final'],
      original: 'atender consultas de licencias y facturacion'
    )
  end

  # El Contexto lo cita el agente como si fuera cierto: la instrucción tiene que
  # PROHIBIR agregar datos, no solo no pedirlos.
  it 'le prohíbe al modelo agregar, quitar o cambiar datos' do
    modelo_devuelve(texto: 'x', cambios: [])

    corregir('Horario de 9 a 18', kind: 'ai_context')

    expect(instruccion_enviada).to include('agregar datos que el texto no dice').and include('quitar datos')
  end

  it 'le dice qué campo es, para que no le cambie la forma' do
    modelo_devuelve(texto: 'x', cambios: [])

    corregir('Horario de 9 a 18', kind: 'ai_context')

    expect(instruccion_enviada).to include('el CONTEXTO del agente')
  end

  it 'trata cualquier otro campo como el objetivo' do
    modelo_devuelve(texto: 'x', cambios: [])

    corregir('algo', kind: 'inventado')

    expect(instruccion_enviada).to include('el OBJETIVO del agente')
  end

  # Las frases del cliente las compara el clasificador con mensajes reales: la
  # instrucción tiene que pedir que NO se formalicen.
  it 'le pide que no formalice las frases del cliente' do
    modelo_devuelve(texto: 'x', cambios: [])

    corregir('no me deja entrar, se traba', kind: 'route_phrases')

    expect(instruccion_enviada).to include('NO LAS FORMALICES')
  end

  describe 'lo que no puede cambiar' do
    # El motor lee las directivas con patrones exactos: una tilde de más las apaga.
    it 'descarta la corrección que tocó una directiva' do
      modelo_devuelve(texto: 'Consultá @búscar_articulo antes de responder.', cambios: ['acentos'])

      resultado = corregir('consulta @buscar_articulo antes de responder', kind: 'section_body')

      expect(resultado).to eq(error: :changed_protected, lost: ['@buscar_articulo'])
    end

    it 'descarta la corrección que cambió un número' do
      modelo_devuelve(texto: 'Horario de 9 a 19 hs.', cambios: ['puntuación'])

      expect(corregir('horario de 9 a 18 hs', kind: 'ai_context')[:lost]).to eq(['18'])
    end

    it 'descarta la corrección que perdió una etiqueta o una marca' do
      modelo_devuelve(texto: 'Cerrá con la etiqueta de soporte. Falta el horario.', cambios: [])

      resultado = corregir('cerra con #soporte. <PENDIENTE: horario>', kind: 'section_body')

      expect(resultado[:lost]).to contain_exactly('#soporte', '<PENDIENTE: horario>')
    end

    # Contado, no solo presente: si el original repite un número, la corrección también.
    it 'cuenta las repeticiones' do
      modelo_devuelve(texto: 'De 9 a 18 hs y los sábados.', cambios: [])

      expect(corregir('de 9 a 18 hs y los sabados de 9 a 13', kind: 'ai_context')[:lost]).to contain_exactly('9', '13')
    end

    it 'deja pasar la corrección que conserva todo lo protegido' do
      modelo_devuelve(texto: 'Consultá @buscar_articulo y {{doc:Manual}}; cerrá con #soporte.', cambios: ['acentos'])

      resultado = corregir('consulta @buscar_articulo y {{doc:Manual}}; cerra con #soporte', kind: 'section_body')

      expect(resultado[:text]).to eq('Consultá @buscar_articulo y {{doc:Manual}}; cerrá con #soporte.')
    end
  end

  it 'rechaza un texto vacío sin gastar una llamada' do
    expect(corregir('   ')).to eq(error: :blank_text)
    expect(WebMock).not_to have_requested(:post, ContactTrackings::Assistant::OpenaiChat::API_URL)
  end

  it 'rechaza un texto más largo que el tope' do
    expect(corregir('x' * (described_class::MAX_CHARS + 1))).to eq(error: :too_long)
  end

  # Fail-soft como el resto del Asistente: si el modelo no contesta, la pantalla
  # se queda con lo que la persona escribió.
  it 'avisa cuando el modelo no contesta' do
    stub_request(:post, ContactTrackings::Assistant::OpenaiChat::API_URL).to_return(status: 500, body: 'boom')

    expect(corregir('algo')).to eq(error: :model_failed)
  end

  it 'avisa cuando el modelo contesta sin texto' do
    modelo_devuelve(cambios: ['nada'])

    expect(corregir('algo')).to eq(error: :model_failed)
  end
end
