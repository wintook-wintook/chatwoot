# frozen_string_literal: true

require 'rails_helper'

# proyecto@respuestas_predefinidas R1 — lo que se muestra de su vectorización.
RSpec.describe CannedResponse, '#embedding_state' do
  let(:canned) { build(:canned_response) }

  it 'se calcula con lo guardado, si tiene vector y si la cuenta tiene OpenAI' do
    estados = [[nil, true, true], [nil, false, true], [nil, false, false], ['no_key', false, true],
               ['pending', false, true], ['failed', false, true], ['failed', true, true], ['ready', false, false]]
              .map do |guardado, vector, clave|
      canned.embedding_status = guardado
      canned.embedding_state(has_vector: vector, has_key: clave)
    end

    expect(estados).to eq(%w[ready missing no_key missing pending failed stale no_key])
  end

  it 'al guardarla queda en camino (pending) hasta que el job termine' do
    expect(create(:canned_response).reload.embedding_status).to eq('pending')
  end
end
