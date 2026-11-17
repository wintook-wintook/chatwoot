# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AgentTester::Judge do
  let(:judge) { described_class.new(account: create(:account)) }

  it 'sin respuesta no pasa, sin pedir nada al modelo' do
    allow(judge).to receive(:chat)
    expect(judge.call(turns: [], reply: '', expected: 'x')).to include(ok: false)
    expect(judge).not_to have_received(:chat)
  end

  it 'manda la respuesta mala anterior cuando la hay' do
    allow(judge).to receive(:chat).and_return('ok' => true, 'reason' => 'Ya viene en lista.')
    expect(judge.call(turns: [], reply: '1. Tesis', expected: 'en lista', bad_reply: 'Tesis y otras')).to eq(ok: true, reason: 'Ya viene en lista.')
    expect(judge).to have_received(:chat) { |args| expect(JSON.parse(args[:user])).to include('respuesta_mala_anterior' => 'Tesis y otras') }
  end

  it 'sin respuesta mala no la manda' do
    allow(judge).to receive(:chat).and_return('ok' => false, 'reason' => 'No.')
    judge.call(turns: [], reply: 'algo', expected: 'otra cosa')
    expect(judge).to have_received(:chat) { |args| expect(JSON.parse(args[:user])).not_to have_key('respuesta_mala_anterior') }
  end
end
