# frozen_string_literal: true

require 'rails_helper'

# proyecto@asistente_agentes_ia — F2 de docs/importar_prompt_md_plan.md: entender y juntar un encargo.
# OpenAI simulado: estas pruebas miden el código alrededor del modelo, no al modelo (eso se
# midió contra gpt-4o con el banco de §2.1; ver el plan).
RSpec.describe ContactTrackings::Assistant::BriefDigestService do
  let(:account) { create(:account) }
  let(:user)    { create(:user, account: account) }
  let(:api)     { ContactTrackings::Assistant::OpenaiChat::API_URL }

  before do
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' })
  end

  def respuesta(json, usage: { prompt_tokens: 100, completion_tokens: 20 })
    { status: 200, headers: { 'Content-Type' => 'application/json' },
      body: { choices: [{ message: { content: json.to_json } }], usage: usage }.to_json }
  end

  # Contesta según quién llama: el lector o el que junta.
  def modelo(lectura:, juntado: nil)
    stub_request(:post, api).to_return do |request|
      sistema = JSON.parse(request.body)['messages'].first['content']
      respuesta(sistema.start_with?('Juntas') ? juntado : lectura)
    end
  end

  def trozo(texto, index: 0, path: [])
    ContactTrackings::Assistant::BriefChunker::Chunk.new(index: index, path: path, titles: [], text: texto,
                                                         sha256: Digest::SHA256.hexdigest(texto))
  end

  describe ContactTrackings::Assistant::BriefFicha do
    it 'limpia lo que devuelve el modelo y le pone origen a cada punto' do
      ficha, origen = described_class.from_reading(
        { 'modo' => 'Vende', 'objetivo' => 'agendar citas', 'prohibiciones' => ['', 'no diagnosticar'],
          'herramientas' => [{ 'tipo' => 'Agenda', 'para' => 'citas' }, { 'tipo' => 'telepatía', 'para' => 'x' }],
          'temas' => [{ 'nombre' => 'cita', 'frases_cliente' => 'quiero una cita' }, { 'que_hace' => 'sin nombre' }] }, 3
      )

      expect(ficha).not_to have_key('modo') # "Vende" no es un modo del motor
      expect(ficha['prohibiciones']).to eq([{ 'texto' => 'no diagnosticar', 'ids' => ['3.2'] }])
      expect(ficha['herramientas'].pluck('tipo')).to eq(%w[agenda otra])
      expect(ficha['temas']).to contain_exactly(hash_including('nombre' => 'cita', 'frases_cliente' => ['quiero una cita']))
      expect(origen.values.uniq).to eq([[3]])
    end

    it 'corta un punto que es un párrafo copiado' do
      ficha, = described_class.from_reading({ 'reglas' => ['x' * 2_000] }, 0)

      expect(ficha['reglas'].first['texto'].length).to eq(described_class::MAX_ITEM_CHARS)
    end
  end

  describe ContactTrackings::Assistant::BriefReader do
    it 'devuelve la ficha del trozo y los tokens usados' do
      modelo(lectura: { 'objetivo' => 'cobrar facturas vencidas', 'modo' => 'responde' })

      resultado = described_class.new(account, chunk: trozo('Cobrá con cariño.'), filename: 'e.md').call

      expect(resultado[:ficha]['objetivo']['texto']).to eq('cobrar facturas vencidas')
      expect(resultado[:usage]).to eq('prompt_tokens' => 100, 'completion_tokens' => 20)
    end

    # Medido con el Vendedor Catálogo: el modelo copiaba la #etiqueta de una ruta sí y de otra no.
    it 'completa los temas con las líneas @ruta que lee el parser del motor' do
      modelo(lectura: { 'temas' => [{ 'nombre' => 'Información de carrera' }] })
      texto = "@ruta(informacion_carrera #info: quiere saber de una carrera): @buscar_predefinidas\n" \
              "@ruta(pagos #pagos: cuánto cuesta): -\n[ROL]\nx"

      temas = described_class.new(account, chunk: trozo(texto), filename: 'e.md').call[:ficha]['temas']

      expect(temas).to contain_exactly(
        hash_including('nombre' => 'Información de carrera', 'etiqueta' => 'info', 'fuente' => '@buscar_predefinidas',
                       'frases_cliente' => ['quiere saber de una carrera']),
        hash_including('nombre' => 'pagos', 'etiqueta' => 'pagos')
      )
    end

    it 'reintenta una vez y después avisa que no pudo' do
      stub_request(:post, api).to_return(status: 500, body: 'x')

      expect(described_class.new(account, chunk: trozo('x'), filename: 'e.md').call[:error]).to eq(:unavailable)
      expect(a_request(:post, api)).to have_been_made.twice
    end
  end

  describe ContactTrackings::Assistant::BriefMerger do
    def parcial(indice, ficha)
      ContactTrackings::Assistant::BriefFicha.from_reading(ficha, indice).then { |f, o| { ficha: f, origin: o } }
    end

    it 'con una sola ficha no llama al modelo' do
      stub_request(:post, api)
      resultado = described_class.new(account, partials: [parcial(0, { 'reglas' => ['una'] })]).call

      expect(resultado[:ficha]['reglas']).to eq([{ 'texto' => 'una', 'origen' => [0] }])
      expect(a_request(:post, api)).not_to have_been_made
    end

    it 'une lo repetido y guarda de qué trozos salió' do
      modelo(lectura: {}, juntado: { 'reglas' => [{ 'texto' => 'una pregunta por mensaje', 'ids' => ['0.1', '1.1', 'inventado'] }] })
      partes = [parcial(0, { 'reglas' => ['una sola pregunta'] }), parcial(1, { 'reglas' => ['no encadenar preguntas'] })]

      ficha = described_class.new(account, partials: partes).call[:ficha]

      expect(ficha['reglas']).to eq([{ 'texto' => 'una pregunta por mensaje', 'origen' => [0, 1] }])
    end

    # La lección de LostRules: al resumir, el modelo borra prohibiciones.
    it 'vuelve a poner una prohibición o un tema que el modelo borró' do
      modelo(lectura: {}, juntado: { 'prohibiciones' => [{ 'texto' => 'no amenazar', 'ids' => ['0.1'] }] })
      partes = [parcial(0, { 'prohibiciones' => ['no amenazar'] }),
                parcial(1, { 'prohibiciones' => ['no prometer reembolsos'], 'temas' => [{ 'nombre' => 'reembolso' }] })]

      ficha = described_class.new(account, partials: partes).call[:ficha]

      expect(ficha['prohibiciones'].pluck('texto')).to eq(['no amenazar', 'no prometer reembolsos'])
      expect(ficha['temas'].pluck('nombre')).to eq(['reembolso'])
    end

    # Medido con ADAM: juntar todo de una vez cortaba la respuesta o pasaba los 180 s.
    it 'junta cada familia por separado' do
      stub_request(:post, api).to_return do |request|
        entrada = JSON.parse(JSON.parse(request.body)['messages'].last['content'])
        respuesta(entrada.transform_values { |puntos| [{ 'texto' => 'junto', 'ids' => puntos.flat_map { |p| p['ids'] } }] })
      end
      partes = [parcial(0, { 'reglas' => ['a'], 'tono' => ['b'] }), parcial(1, { 'reglas' => ['c'], 'tono' => ['d'] })]

      resultado = described_class.new(account, partials: partes).call

      expect(resultado[:calls]).to eq(2) # núcleo (tono) y normas (reglas)
      expect(resultado[:ficha]['reglas']).to eq([{ 'texto' => 'junto', 'origen' => [0, 1] }])
      expect(resultado[:ficha]['tono']).to eq([{ 'texto' => 'junto', 'origen' => [0, 1] }])
    end

    it 'una familia muy grande se junta por tandas' do
      stub_const("#{described_class}::MAX_INPUT_CHARS", 80)
      stub_request(:post, api).to_return do |request|
        entrada = JSON.parse(JSON.parse(request.body)['messages'].last['content'])
        respuesta({ 'reglas' => [{ 'texto' => 'r', 'ids' => entrada['reglas'].flat_map { |p| p['ids'] } }] })
      end
      partes = (0..3).map { |i| parcial(i, { 'reglas' => ["regla número #{i} con texto"] }) }

      resultado = described_class.new(account, partials: partes).call

      expect(resultado[:calls]).to be > 1
      expect(resultado[:ficha]['reglas']).to eq([{ 'texto' => 'r', 'origen' => [0, 1, 2, 3] }])
    end

    it 'si la respuesta se corta, avisa que no pudo' do
      stub_request(:post, api).to_return(status: 200, body: { choices: [{ finish_reason: 'length', message: { content: '{' } }] }.to_json)
      partes = [parcial(0, { 'reglas' => ['a'] }), parcial(1, { 'reglas' => ['b'] })]

      expect(described_class.new(account, partials: partes).call[:error]).to eq(:unavailable)
    end
  end

  describe ContactTrackings::Assistant::BriefContradictions do
    let(:ficha) do
      { 'reglas' => [{ 'texto' => 'Preguntar si es estudiante antes del precio', 'origen' => [0] },
                     { 'texto' => 'Una sola pregunta por mensaje', 'origen' => [0] },
                     { 'texto' => 'Dar el precio sin preguntar nada antes', 'origen' => [1] }] }
    end

    def choques(json)
      stub_request(:post, api).to_return(respuesta(json))
      described_class.new(account, ficha: ficha).call[:ficha]['contradicciones']
    end

    # Medido con el gimnasio: el lector las marcaba en una lectura y en la otra no.
    it 'arma cada contradicción con el texto de las reglas, no con el del modelo' do
      resultado = choques({ 'contradicciones' => [{ 'sobre' => 'precio', 'a' => 1, 'b' => 3 }] })

      expect(resultado).to eq([{ 'sobre' => 'precio', 'a' => 'Preguntar si es estudiante antes del precio',
                                 'b' => 'Dar el precio sin preguntar nada antes', 'origen' => [0, 1] }])
    end

    it 'descarta números que no existen o que se repiten' do
      expect(choques({ 'contradicciones' => [{ 'a' => 1, 'b' => 9 }, { 'a' => 2, 'b' => 2 }] })).to eq([])
    end

    it 'no repite una que el lector ya había anotado' do
      ficha['contradicciones'] = [{ 'sobre' => 'x', 'a' => 'Dar el precio sin preguntar nada antes',
                                    'b' => 'Preguntar si es estudiante antes del precio' }]

      expect(choques({ 'contradicciones' => [{ 'sobre' => 'precio', 'a' => 1, 'b' => 3 }] }).size).to eq(1)
    end
  end

  describe ContactTrackings::Assistant::BriefGaps do
    let(:inventario) { ContactTrackings::Assistant::InventoryService.new(account).call }

    def faltas(ficha)
      described_class.new(ficha, inventory: inventario).call.map { |g| g.values_at('paso', 'que', 'tema', 'tipo').compact }
    end

    it 'sin temas ni modo, pregunta el paso 1' do
      expect(faltas({})).to eq([[1, 'temas'], [1, 'modo']])
    end

    it 'pregunta frases, fuente y una sola vez las etiquetas si ningún tema las trae' do
      ficha = { 'modo' => { 'texto' => 'deriva' }, 'temas' => [{ 'nombre' => 'reclamo' }, { 'nombre' => 'urgencia', 'fuente' => 'x' }] }

      expect(faltas(ficha)).to eq([[2, 'frases_cliente', 'reclamo'], [2, 'frases_cliente', 'urgencia'],
                                   [3, 'fuente_o_escalamiento', 'reclamo'], [4, 'etiquetas']])
    end

    # El modelo las anota pero no las resuelve: las decide la persona, antes que nada.
    it 'pone primero las contradicciones del encargo' do
      ficha = { 'modo' => { 'texto' => 'responde' }, 'temas' => [{ 'nombre' => 'precios', 'fuente' => 'hoja',
                                                                   'frases_cliente' => ['cuánto'], 'etiqueta' => 'p' }],
                'contradicciones' => [{ 'sobre' => 'precio', 'a' => 'preguntar antes', 'b' => 'no preguntar' }] }

      expect(described_class.new(ficha, inventory: inventario).call)
        .to eq([{ 'paso' => 0, 'que' => 'contradiccion', 'sobre' => 'precio', 'a' => 'preguntar antes', 'b' => 'no preguntar' }])
    end

    # Un encargo de cobranza que lee una hoja de Google en una cuenta sin hojas conectadas.
    it 'avisa las herramientas que la cuenta no tiene' do
      ficha = { 'modo' => { 'texto' => 'responde' },
                'herramientas' => [{ 'tipo' => 'hoja', 'para' => 'saldos' }, { 'tipo' => 'persona', 'para' => 'x' }] }

      expect(faltas(ficha)).to include([3, 'herramienta_no_disponible', 'hoja'])
      expect(ficha['herramientas'].pluck('disponible')).to eq([false, nil])
    end
  end

  describe '#call' do
    let(:texto) { "[ROL]\nAgenda citas.\n[PROHIBIDO]\nNunca diagnosticar." }

    def encargo(contenido = texto)
      TrackingAgentBrief.create!(account: account, user: user, filename: 'e.md', content: contenido,
                                 sha256: TrackingAgentBrief.fingerprint(contenido))
    end

    it 'deja el encargo leído, con la ficha, lo que falta y lo que costó' do
      modelo(lectura: { 'objetivo' => 'agendar citas', 'prohibiciones' => ['nunca diagnosticar'] })

      brief = described_class.new(encargo).call

      expect(brief.status).to eq('ready')
      expect(brief.digest['ficha']['objetivo']).to eq('texto' => 'agendar citas', 'origen' => [0])
      expect(brief.digest['faltas']).to include(hash_including('paso' => 1, 'que' => 'temas'))
      expect(brief.usage).to include('trozos' => 1, 'trozos_reusados' => 0, 'modelo' => 'gpt-4o')
      expect(brief.chunks.first).to include('sha256', 'lectura')
      expect(brief.chunks.first).not_to have_key('text')
    end

    it 'no vuelve a pagar un trozo que la cuenta ya leyó' do
      modelo(lectura: { 'objetivo' => 'agendar citas' })
      described_class.new(encargo).call
      WebMock.reset_executed_requests!

      otro = described_class.new(encargo).call

      expect(a_request(:post, api)).not_to have_been_made
      expect(otro.usage).to include('trozos_reusados' => 1)
      expect(otro.digest['ficha']['objetivo']['texto']).to eq('agendar citas')
    end

    # Cambiar las instrucciones del lector invalida lo leído con las anteriores.
    it 'no reusa una lectura hecha con otra versión del lector' do
      modelo(lectura: { 'objetivo' => 'agendar citas' })
      viejo = described_class.new(encargo).call
      viejo.update!(chunks: viejo.chunks.map { |c| c.merge('lector' => ContactTrackings::Assistant::BriefReader::VERSION - 1) })
      WebMock.reset_executed_requests!

      otro = described_class.new(encargo).call

      expect(a_request(:post, api)).to have_been_made.once
      expect(otro.usage).to include('trozos_reusados' => 0)
    end

    it 'si falla, queda en failed' do
      stub_request(:post, api).to_return(status: 500, body: 'x')

      brief = described_class.new(encargo).call

      expect(brief).to have_attributes(status: 'failed')
      expect(brief.usage['error']).to eq('reading')
    end

    it 'sin clave de OpenAI, lo dice' do
      Integrations::Hook.where(account: account).delete_all

      expect(described_class.new(encargo).call.usage['error']).to eq('no_api_key')
    end
  end
end
