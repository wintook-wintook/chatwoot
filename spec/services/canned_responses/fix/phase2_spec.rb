# frozen_string_literal: true

require 'rails_helper'

# proyecto@arreglar_predefinidas F2 — redacción, unir, separar, resolver y deshacer.
RSpec.describe 'Arreglos con IA de la auditoría' do # rubocop:disable RSpec/DescribeClass
  let(:account) { create(:account) }

  describe CannedResponses::Fix::Diff do
    it 'mide la parte de palabras que cambió' do
      expect(described_class.ratio('a b c d', 'a b c d')).to eq(0.0)
      expect(described_class.ratio('a b c d', 'a x c d')).to eq(0.25)
      expect(described_class.changed_words('a b c d', 'a x c d')).to eq(2)
    end
  end

  describe CannedResponses::Fix::Resolution do
    let(:contradicciones) do
      [{ 'topic' => 'precio', 'quote_a' => 'Cuesta $1,500 al mes.', 'quote_b' => 'La colegiatura es de $1,800.' },
       { 'topic' => 'servicio social', 'quote_a' => 'Se requiere servicio social.', 'quote_b' => 'No se requiere servicio social.' }]
    end

    it 'con A correcto prohíbe el dato de B y exige el de A; sin datos duros, prohíbe la cita perdedora' do
      r = described_class.new(contradicciones, [{ 'choice' => 'a' }, { 'choice' => 'b' }])

      expect(r.forbidden.map { |i| [i['kind'], i['text']] }).to eq([%w[money $1,800], ['sentence', 'Se requiere servicio social.']])
      expect(r.required.pluck('text')).to eq(['$1,500'])
      expect(r.wrong_data.pluck('text')).to eq(['$1,800'])
      expect(r.complete?(2)).to be(true)
    end

    it 'con un valor propio, lo de las dos citas que no es ese valor queda prohibido' do
      r = described_class.new(contradicciones.first(1), [{ 'choice' => 'custom', 'value' => '$1,650' }])

      expect(r.forbidden.pluck('text')).to eq(['$1,500', '$1,800'])
      expect(r.required.pluck('text')).to eq(['$1,650'])
    end

    it 'sin elección no está completa' do
      expect(described_class.new(contradicciones, [{ 'choice' => 'a' }]).complete?(2)).to be(false)
    end
  end

  describe 'aplicar y deshacer' do
    let!(:a) { create(:canned_response, account: account, short_code: 'Precio X', content: 'X cuesta $1,500.', kind: 'ficha') }
    let!(:b) { create(:canned_response, account: account, short_code: 'Costo X', content: 'La colegiatura de X es de $1,800.') }

    def fix(kind, partes, sources: [a, b], input: {})
      account.canned_response_fixes.create!(
        kind: kind, status: 'proposed', canned_response: sources.first, source_ids: sources.map(&:id),
        source_digests: sources.to_h { |r| [r.id.to_s, CannedResponseFix.digest_for(r)] }, input: input,
        proposal: { 'action' => kind, 'parts' => partes, 'questions' => [] }
      )
    end

    it 'unir: se queda la que no es General, toma el texto unido y la otra se elimina; deshacer las regresa' do
      arreglo = fix('merge', [{ 'short_code' => 'Precio X', 'content' => 'X cuesta $1,500. La colegiatura es de $1,800.' }])

      CannedResponses::Fix::Applier.new(arreglo).call(parts: arreglo.proposal['parts'])

      expect(account.canned_responses.pluck(:id, :content)).to eq([[a.id, 'X cuesta $1,500. La colegiatura es de $1,800.']])
      expect(arreglo.reload.result).to include('deleted_ids' => [b.id], 'updated_ids' => [a.id])

      CannedResponses::Fix::Undo.new(arreglo).call
      expect(account.canned_responses.order(:id).pluck(:id, :short_code, :content))
        .to eq([[a.id, 'Precio X', 'X cuesta $1,500.'], [b.id, 'Costo X', 'La colegiatura de X es de $1,800.']])
      expect(arreglo.reload.status).to eq('undone')
    end

    it 'resolver: bloquea si queda el dato equivocado; corrige las dos sin cambiar nombres' do
      entrada = { 'contradictions' => [{ 'topic' => 'precio', 'quote_a' => 'X cuesta $1,500.', 'quote_b' => 'es de $1,800' }],
                  'choices' => [{ 'choice' => 'a' }] }
      mala = [{ 'short_code' => 'otro', 'content' => 'X cuesta $1,500.' }, { 'short_code' => 'Costo X', 'content' => 'Es de $1,800.' }]
      arreglo = fix('resolve', mala, input: entrada)

      expect { CannedResponses::Fix::Applier.new(arreglo).call(parts: mala) }
        .to raise_error(CannedResponses::Fix::Applier::Blocked) { |e| expect(e.checks['blocking']).to eq(['resolved']) }

      buena = [mala.first, { 'short_code' => 'Costo X', 'content' => 'La colegiatura de X es de $1,500.' }]
      CannedResponses::Fix::Applier.new(arreglo).call(parts: buena)
      expect(account.canned_responses.order(:id).pluck(:short_code, :content))
        .to eq([['Precio X', 'X cuesta $1,500.'], ['Costo X', 'La colegiatura de X es de $1,500.']])
    end

    it 'separar: perder frases bloquea, salvo que se confirme' do
      a.update!(content: 'Precio de X: $1,500 al mes, pagadero en efectivo o tarjeta en cualquier sucursal.')
      arreglo = fix('separate', [{ 'short_code' => 'Precio X', 'content' => '$1,500' }, { 'short_code' => 'Costo X', 'content' => b.content }])
      partes = arreglo.proposal['parts']

      expect { CannedResponses::Fix::Applier.new(arreglo).call(parts: partes) }
        .to raise_error(CannedResponses::Fix::Applier::Blocked) { |e| expect(e.checks['blocking']).to include('coverage') }
      expect { CannedResponses::Fix::Applier.new(arreglo).call(parts: partes, force: true) }.not_to raise_error
    end

    it 'redacción: no cuenta como reescritura de más un cambio chico en un texto corto' do
      arreglo = fix('writing', [{ 'short_code' => 'Precio X', 'content' => 'X cuesta $1,500 al mes.' }], sources: [a])
      revision = CannedResponses::Fix::Context.for(arreglo).checks.call(arreglo.proposal['parts'], [], embeddings: false)

      expect(revision['changes']['ok']).to be(true)
      expect(revision['blocking']).to eq([])
    end

    it 'deshacer avisa si alguien editó después lo que dejó el arreglo' do
      arreglo = fix('writing', [{ 'short_code' => 'Precio X', 'content' => 'X cuesta $1,500 al mes.' }], sources: [a])
      CannedResponses::Fix::Applier.new(arreglo).call(parts: arreglo.proposal['parts'])
      a.reload.update!(content: 'Lo editó alguien después: X cuesta $1,500.')

      expect { CannedResponses::Fix::Undo.new(arreglo.reload).call }.to raise_error(CannedResponses::Fix::Undo::Conflict)
      CannedResponses::Fix::Undo.new(arreglo).call(force: true)
      expect(a.reload.content).to eq('X cuesta $1,500.')
    end

    it 'dividir (pasa del tope) también se deshace: borra las partes y regresa la original con su id' do
      arreglo = fix('oversize', [{ 'short_code' => 'X — 1', 'content' => 'X cuesta $1,500.' }, { 'short_code' => 'X — 2', 'content' => 'Más.' }],
                    sources: [a])
      arreglo.update!(proposal: arreglo.proposal.merge('action' => 'split'))
      CannedResponses::Fix::Applier.new(arreglo).call(parts: arreglo.proposal['parts'])
      expect(account.canned_responses.pluck(:short_code)).to contain_exactly('Costo X', 'X — 1', 'X — 2')

      CannedResponses::Fix::Undo.new(arreglo.reload).call
      expect(account.canned_responses.order(:id).pluck(:id, :short_code)).to eq([[a.id, 'Precio X'], [b.id, 'Costo X']])
    end
  end

  describe 'constructores con la IA simulada' do
    let(:chat) { instance_double(ContactTrackings::Assistant::OpenaiChat, last_error: nil) }
    let!(:a) do
      create(:canned_response, account: account, short_code: 'Horario', content: 'Abrimos de lunes a viernes de 9:00 a 18:00 hrs. Llamenos.')
    end
    let!(:b) { create(:canned_response, account: account, short_code: 'Horarios', content: 'Horario: lunes a viernes, 9:00 a 18:00.') }

    before do
      create(:integrations_hook, :openai, account: account)
      allow(ContactTrackings::Assistant::OpenaiChat).to receive(:new).and_return(chat)
      allow(chat).to receive(:api_key).and_return('sk-test')
      allow(CannedResponses::Fix::Embedder).to receive(:new).and_return(instance_double(CannedResponses::Fix::Embedder, call: nil))
    end

    it 'redacción: corrige solo lo señalado y no pide segunda vuelta si el cambio es chico' do
      allow(chat).to receive(:call).and_return('short_code' => 'Horario', 'content' => 'Abrimos de lunes a viernes de 9:00 a 18:00 hrs. Llámenos.')
      contexto = CannedResponses::Fix::Context.new(account, kind: 'writing', sources: [a],
                                                            input: { 'issues' => [{ 'type' => 'ortografia', 'quote' => 'Llamenos' }] })

      salida = CannedResponses::Fix::WritingBuilder.new(contexto).call

      expect(chat).to have_received(:call).once
      expect(salida[:proposal]['parts'].sole['content']).to end_with('Llámenos.')
      expect(salida[:checks]['blocking']).to eq([])
    end

    it 'unir: la primera parte lleva el nombre de la que se conserva' do
      parte = { 'short_code' => 'otro nombre', 'content' => 'Lunes a viernes de 9:00 a 18:00 hrs. Llámenos.' }
      allow(chat).to receive(:call).and_return('parts' => [parte], 'questions' => [{ 'text' => '¿A qué hora abren?', 'part' => 0 }])
      contexto = CannedResponses::Fix::Context.new(account, kind: 'merge', sources: [a, b])

      salida = CannedResponses::Fix::MergeBuilder.new(contexto).call

      expect(salida[:proposal]['parts'].first['short_code']).to eq('Horario')
      expect(salida[:proposal]).to include('target_id' => a.id, 'removed_id' => b.id)
    end

    it 'separar: la IA puede desaconsejarlo y no hay nada que aplicar' do
      allow(chat).to receive(:call).and_return('not_advised' => true, 'reason' => 'son variantes que se leen solas')
      contexto = CannedResponses::Fix::Context.new(account, kind: 'separate', sources: [a, b])

      salida = CannedResponses::Fix::SeparateBuilder.new(contexto).call

      expect(salida[:proposal]).to include('not_advised' => true, 'reason' => 'son variantes que se leen solas')
      expect(chat).to have_received(:call).once
    end
  end
end
