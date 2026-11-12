require 'rails_helper'

# proyecto@crear_agente_conversando FR — las herramientas del chat de creación.
RSpec.describe ContactTrackings::Assistant::AssistantTools do
  subject(:tools) { described_class.new(account, draft: boceto, api_key: 'sk-test') }

  let(:account) { create(:account) }
  let(:boceto) { "@ruta(cotizar #cotizacion: cuánto cuesta): -\n@ruta_por_defecto: cotizar" }

  def run(nombre, args = {}) = JSON.parse(tools.run(nombre, args.to_json))

  it 'ver_recursos dice lo que tiene y lo que no' do
    create(:label, account: account, title: 'cotizacion')
    resultado = run('ver_recursos')
    expect(resultado['etiquetas']).to eq(['cotizacion'])
    expect(resultado['no_tiene']).to include('google_sheet')
  end

  it 'ver_fuente con un nombre que no existe dice cuáles hay' do
    create(:knowledge_source, account: account, source_type: 'discourse', name: 'Foro Kontrolya')
    expect(run('ver_fuente', nombre: 'Precios')).to include('error', 'fuentes' => ['Foro Kontrolya'])
  end

  it 'probar_fuente avisa que el foro se consulta en vivo' do
    create(:knowledge_source, account: account, source_type: 'discourse', name: 'Foro Kontrolya')
    expect(run('probar_fuente', nombre: 'Foro Kontrolya', frase: 'no puedo timbrar')).to include('en_vivo' => true)
  end

  it 'probar_fuente busca de verdad y dice si pasa el umbral' do
    fuente = create(:knowledge_source, account: account, source_type: 'canned_response', name: 'Respuestas predefinidas')
    create(:knowledge_item, account: account, knowledge_source: fuente, title: 'Precio de la grúa',
                            content: 'La plataforma cuesta $1,800', embedding: Array.new(1536, 0.1))
    stub_request(:post, 'https://api.openai.com/v1/embeddings')
      .to_return(status: 200, body: { data: [{ embedding: Array.new(1536, 0.1) }] }.to_json)
    resultado = run('probar_fuente', nombre: 'predefinidas', frase: 'cuánto cuesta la grúa')
    expect(resultado['encontrado'].first).to include('titulo' => 'Precio de la grúa', 'pasa_umbral' => true)
  end

  it 'probar_ruta clasifica dos veces cada frase con el boceto' do
    clasificador = instance_double(ContactTrackings::Assistant::DraftClassifier)
    allow(ContactTrackings::Assistant::DraftClassifier).to receive(:new).and_return(clasificador)
    allow(clasificador).to receive(:classify).and_return(Struct.new(:name).new('cotizar'))
    resultado = run('probar_ruta', frases: ['precio de la grúa'])
    expect(resultado).to eq([{ 'frase' => 'precio de la grúa', 'cae_en' => 'cotizar', 'veces' => '2/2', 'estable' => true }])
    expect(tools.tested).to eq([{ frase: 'precio de la grúa', cae_en: 'cotizar', veces: '2/2', estable: true }])
  end

  it 'probar_ruta sin rutas lo dice' do
    expect(described_class.new(account).run('probar_ruta', { frases: ['hola'] }.to_json)).to include('ninguna línea @ruta')
  end

  it 'comprobar pasa el boceto por el comprobador' do
    expect(run('comprobar', rutas: '@ruta(roto: x')).to include('ejecuta' => false)
  end

  it 'una herramienta que no existe o que truena vuelve como dato' do
    expect(run('borrar_todo')).to include('error')
    allow(ContactTrackings::Assistant::SourceProfiles).to receive(:new).and_raise('se cayó')
    expect(run('ver_fuente', nombre: 'x')).to include('error' => 'se cayó')
  end
end
