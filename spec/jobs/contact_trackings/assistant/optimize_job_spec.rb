# frozen_string_literal: true

# proyecto@asistente_agentes_ia — optimizar en segundo plano
require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::OptimizeJob do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:turn_id) { 'tabc12345' }
  let(:progress) { ContactTrackings::Assistant::TurnProgress }

  after { Redis::Alfred.delete(progress.result_key(account, user, turn_id)) }

  it 'guarda el resultado del Optimizer' do
    optimizer = instance_double(ContactTrackings::Assistant::Optimizer, call: { findings: [], summary: 'ok' })
    allow(ContactTrackings::Assistant::Optimizer).to receive(:new).and_return(optimizer)

    described_class.perform_now(account.id, user.id, turn_id, 'borrador')

    expect(progress.read_result(account, user, turn_id)).to eq('findings' => [], 'summary' => 'ok')
  end

  it 'guarda un error si el Optimizer revienta, para que la pantalla no espere en vano' do
    allow(ContactTrackings::Assistant::Optimizer).to receive(:new).and_raise(StandardError, 'boom')

    described_class.perform_now(account.id, user.id, turn_id, 'borrador')

    expect(progress.read_result(account, user, turn_id)).to eq('error' => 'unavailable')
  end
end
