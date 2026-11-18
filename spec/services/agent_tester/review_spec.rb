# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AgentTester::Review do
  let(:account) { create(:account) }
  let(:template) { create(:tracking_template, account: account) }

  def log(conversation_id, canned_id, status: 'pending')
    AgentTestLog.create!(account: account, tracking_template: template, engine: '1', kind: 'search', status: status,
                         conversation_id: conversation_id, diagnosis: { 'canned_id' => canned_id })
  end

  it 'junta por plática, pendientes primero, y dice qué otros pendientes apuntan a la misma respuesta' do
    a = log(1, 7)
    b = log(2, 7)
    c = log(2, 9, status: 'passed')
    grupos = described_class.group([a, b, c])

    expect(grupos.map { |g| [g[:conversation_id], g[:open], g[:total]] }).to eq([[1, 1, 1], [2, 1, 2]])
    expect(grupos.first[:same_canned][a.id]).to eq([b.id])
    expect(grupos.last[:same_canned][c.id]).to eq([])
  end
end
