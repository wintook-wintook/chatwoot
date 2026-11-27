# frozen_string_literal: true

require 'rails_helper'

# proyecto@crear_agente_conversando §15 — probar las fuentes como las busca el agente.
RSpec.describe ContactTrackings::Assistant::SourceProbe do
  let(:account) { create(:account) }
  let(:fuente) { create(:knowledge_source, account: account, source_type: 'canned_response') }
  let(:texto) do
    "[ROL]\nEres Leo.\n@ruta(dudas #duda: tengo una duda): @buscar_predefinidas(PATITAS)\n" \
      "@ruta(precios: cuánto cuesta): {{hoja_buscar: Precios | Producto=? | Precio}} -> -\n" \
      "@ruta(otra: otra cosa): @buscar_predefinidas(PATITAS)\n@ruta_por_defecto: dudas"
  end

  # Un vector cuyo parecido (coseno) con la frase es exactamente `parecido`.
  def vector(parecido) = [parecido, Math.sqrt(1 - (parecido**2)), *Array.new(1534, 0.0)]

  def predefinida(titulo, parecido)
    create(:knowledge_item, account: account, knowledge_source: fuente, title: titulo,
                            content: "Texto de #{titulo}", embedding: vector(parecido))
  end

  def probar(directiva, frase = '¿cuánto cuesta la consulta?')
    stub_request(:post, 'https://api.openai.com/v1/embeddings')
      .to_return(status: 200, body: { data: [{ embedding: [1.0, *Array.new(1535, 0.0)] }] }.to_json)
    described_class.new(account, text: texto, api_key: 'sk-test').run(directiva, frase)
  end

  it 'lista las directivas del Entrenamiento con las rutas que las usan' do
    lista = described_class.new(account, text: texto).directives

    expect(lista.map { |d| d.slice(:directive, :kind, :routes) }).to eq(
      [{ directive: '@buscar_predefinidas(PATITAS)', kind: 'similarity', routes: %w[dudas otra] },
       { directive: '{{hoja_buscar: Precios | Producto=? | Precio}}', kind: 'sheet_lookup', routes: ['precios'] }]
    )
    expect(lista.first).to include(group: 'PATITAS', mode: :canned_response, items: 0)
    expect(lista.last).not_to have_key(:items)
  end

  it 'con grupo busca solo en él, con el umbral de grupo, y dice por qué quedó fuera cada una' do
    predefinida('PATITAS_CONSULTA', 0.9)
    predefinida('PATITAS_VACUNAS', 0.5)
    predefinida('PATITAS_HORARIO', 0.4)
    predefinida('TERAPIA_SESION', 0.95)

    resultado = probar('@buscar_predefinidas(PATITAS)')

    expect(resultado).to include(kind: 'similarity', threshold: 0.45, threshold_from: 'group', max_results: 3, used: 2)
    expect(resultado[:results].map { |r| [r[:title], r[:used], r[:reason], r[:weak]] }).to eq(
      [['PATITAS_CONSULTA', true, nil, false], ['PATITAS_VACUNAS', true, nil, true],
       ['PATITAS_HORARIO', false, 'below_threshold', true]]
    )
  end

  it 'sin grupo usa el umbral de la cuenta y marca lo que pasa del tope' do
    [0.9, 0.8, 0.7, 0.6].each_with_index { |p, i| predefinida("R#{i}", p) }

    resultado = probar('@buscar_predefinidas')

    expect(resultado).to include(threshold: 0.2, threshold_from: 'account', used: 3)
    expect(resultado[:results].last).to include(title: 'R3', used: false, reason: 'over_limit')
  end

  it 'un grupo sin ninguna respuesta lo dice, en la lista y al probar' do
    predefinida('OTRO_X', 0.9)

    expect(described_class.new(account, text: texto).directives.first).to include(items: 0)
    expect(probar('@buscar_predefinidas(PATITAS)')).to eq(kind: 'similarity', error: 'empty_source')
  end

  it 'un documento sin Google activo en la cuenta: el agente no buscaría' do
    expect(probar('{{doc:Precios}}')).to include(kind: 'similarity', error: 'google_disabled')
  end

  it 'cada tipo va a su prueba: hojas y ERP (P2), en vivo (P3)' do
    expect(probar('{{hoja_buscar: Precios | Producto=? | Precio}}')).to eq(kind: 'sheet_lookup', error: 'google_disabled')
    expect(probar('{{consulta:sae/saldo(rfc=?)}}')).to eq(kind: 'erp', error: 'query_missing')
    expect(probar('@buscar_foro(Foro)')).to eq(kind: 'live', error: 'source_missing')
    expect(probar('@soporte_contpaq(Soporte)')).to eq(kind: 'live', error: 'source_missing')
    expect(probar('@discourse')).to eq(kind: 'live', error: 'needs_inbox')
  end

  it 'avisa qué hace cada fuente en vivo' do
    lista = described_class.new(account, text: "@buscar_foro(F)\n@soporte_contpaq(S)").directives

    expect(lista.pluck(:notice)).to eq(%w[forum_live contpaq_thread])
  end

  it 'marca cuáles gastan una llamada de IA' do
    lista = described_class.new(account, text: "{{consulta:sae/saldo(rfc=?)}}\n{{consulta:sae/catalogo}}").directives

    expect(lista.map { |d| [d[:kind], d[:uses_ai]] }).to eq([['erp', true], ['erp', false]])
  end

  it 'sin frase o con algo que no es directiva, lo dice' do
    expect(probar('@buscar_predefinidas', ' ')).to eq(error: 'no_phrase')
    expect(probar('hola')).to eq(error: 'unknown_directive')
  end

  it 'sin directivas en el texto ofrece las fuentes de la cuenta' do
    predefinida('R1', 0.5)

    lista = described_class.new(account, text: '[ROL] Eres Leo').directives

    expect(lista.map { |d| [d[:directive], d[:from_account]] }).to eq([['@buscar_predefinidas', true]])
  end
end
