# frozen_string_literal: true

# proyecto@asistente_agentes_ia — fase D de PROMPT STUDIO
require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::TurnProgress do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:turn_id) { 'tabc12345' }

  after do
    Redis::Alfred.delete(described_class.key(account, user, turn_id))
    Redis::Alfred.delete(described_class.result_key(account, user, turn_id))
  end

  # Resultado de un turno que corre en Sidekiq (OptimizeJob).
  it 'guarda el resultado final y solo lo lee quien lo pidió' do
    described_class.store_result(account, user, turn_id, { findings: [], summary: 'ok' })

    expect(described_class.read_result(account, user, turn_id)).to eq('findings' => [], 'summary' => 'ok')
    expect(described_class.read_result(account, create(:user, account: account), turn_id)).to be_nil
  end

  it 'guarda la etapa y la devuelve con sus datos' do
    described_class.new(account, user, turn_id).update(:repairing, round: 2, of: 3)

    expect(described_class.read(account, user, turn_id)).to eq('stage' => 'repairing', 'round' => 2, 'of' => 3)
  end

  # El id lo genera el cliente: el progreso de un turno solo lo lee quien lo mandó.
  it 'no deja leer el progreso de otra persona' do
    described_class.new(account, user, turn_id).update(:checking)

    expect(described_class.read(account, create(:user, account: account), turn_id)).to be_nil
  end

  it 'ignora un id con forma rara y una etapa desconocida' do
    described_class.new(account, user, '../../x').update(:checking)
    described_class.new(account, user, turn_id).update(:inventada)

    expect(described_class.read(account, user, '../../x')).to be_nil
    expect(described_class.read(account, user, turn_id)).to be_nil
  end

  # Que Redis no esté no puede tirar el turno de la persona.
  it 'no rompe si Redis falla' do
    allow(Redis::Alfred).to receive(:setex).and_raise(Redis::CannotConnectError)

    expect { described_class.new(account, user, turn_id).update(:checking) }.not_to raise_error
  end
end
