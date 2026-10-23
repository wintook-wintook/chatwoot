# frozen_string_literal: true

require 'rails_helper'

# Embudo de contactos E3 — métricas desde la bitácora de movimientos.
RSpec.describe Kanban::FunnelMetrics do
  let(:account) { create(:account, locale: 'es') }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:board) { create(:kanban_type_process, account: account).tap { |b| Kanban::FunnelTemplate.new(b).apply! } }
  let(:columns) { board.kanban_processes.by_position.index_by(&:type_process_name) }

  def walk(conversation, *steps)
    steps.each do |name, source, at|
      travel_to(at) do
        conversation.kanban_move_context = { source: source, reason: "a #{name}", user_id: source == 'manual' ? agent.id : nil }
        conversation.update!(kanban_type_process_id: board.id, kanban_process_id: columns[name].id)
      end
    end
  end

  it 'cuenta entradas, alcance por columna, conversión, descartes y aciertos de la IA' do
    won = create(:conversation, account: account, inbox: inbox)
    walk(won, ['Nuevo', 'rule', 10.days.ago], ['Interesado', 'ai', 8.days.ago], ['Convertido', 'rule', 6.days.ago])

    lost = create(:conversation, account: account, inbox: inbox)
    walk(lost, ['Nuevo', 'rule', 5.days.ago], ['Interesado', 'ai', 4.days.ago], ['En contacto', 'manual', 3.days.ago],
         ['Descartado', 'rule', 2.days.ago])

    old = create(:conversation, account: account, inbox: inbox)
    walk(old, ['Nuevo', 'rule', 90.days.ago])

    result = described_class.new(board, days: 30).call

    expect(result[:entries]).to eq(2)
    by_name = result[:columns].index_by { |c| c[:name] }
    expect(by_name['Interesado']).to include(reached: 2, reach_rate: 100.0)
    expect(by_name['Convertido']).to include(reached: 1, current: 1)
    expect(result[:converted]).to include(count: 1, rate: 50.0, avg_days: 4.0)
    expect(result[:discards]).to eq([{ reason: 'a Descartado', count: 1 }])
    expect(result[:sources]).to include('ai' => 2, 'manual' => 1)
    expect(result[:ai]).to eq(moves: 2, corrected: 1, accuracy: 50.0)
  end
end
