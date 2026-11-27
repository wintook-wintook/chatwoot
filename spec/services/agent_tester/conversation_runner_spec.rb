# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AgentTester::ConversationRunner do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:template) { create(:tracking_template, account: account) }
  let(:batch) { AgentTestBatch.create!(account: account, tracking_template: template, name: 'Lote') }
  let(:test_case) do
    batch.cases.create!(account: account, name: 'Lista', messages: ['¿Cómo me titulo?'], expected: 'Debería darlo en lista',
                        bad_reply: 'Tesis, CENEVAL y otras.')
  end
  let(:runner) { described_class.new(template, user: user) }
  let(:judge) { instance_double(AgentTester::Judge, call: { ok: true, reason: 'Cumple.' }) }

  before do
    stub_const("#{described_class}::QUIET", 0)
    stub_const("#{described_class}::POLL", 0)
    allow(AgentTester::Judge).to receive(:new).and_return(judge)
  end

  # El agente contesta desde «otro proceso» mientras el probador espera.
  def answer_after_first_poll
    calls = 0
    allow(runner).to receive(:sleep) do
      calls += 1
      next unless calls == 1

      conversation = Conversation.where(account: account).order(:id).last
      # La escribe «otro proceso» (el motor): no vacía la caché de consultas de esta conexión.
      connection = ActiveRecord::Base.connection
      allow(connection).to receive(:clear_query_cache)
      create(:message, account: account, inbox: conversation.inbox, conversation: conversation, message_type: :outgoing,
                       content: '1. Tesis 2. CENEVAL')
    end
  end

  it 've la respuesta aunque la caché de consultas esté prendida (como dentro de un job)' do
    answer_after_first_poll
    result = ActiveRecord::Base.cache { runner.run(test_case) }
    expect(result).to include(ok: true, reply: '1. Tesis 2. CENEVAL', case_id: test_case.id)
  end

  it 'le pasa al juez la respuesta mala del 👎 y guarda el id de la plática' do
    answer_after_first_poll
    result = runner.run(test_case)
    expect(judge).to have_received(:call).with(hash_including(bad_reply: 'Tesis, CENEVAL y otras.',
                                                              expected: 'Debería darlo en lista'))
    conversation = Conversation.find(result[:conversation_id])
    expect(result[:display_id]).to eq(conversation.display_id)
  end

  it 'al terminar cierra la plática de prueba' do
    answer_after_first_poll
    result = runner.run(test_case)
    expect(Conversation.find(result[:conversation_id])).to be_resolved
  end

  it 'sin agente asignado devuelve el resultado con su prueba (para que la corrida no la repita)' do
    allow_any_instance_of(AgentTester::Sandbox).to receive(:start).and_return(nil) # rubocop:disable RSpec/AnyInstance
    expect(runner.run(test_case)).to include(case_id: test_case.id, ok: false)
  end
end
