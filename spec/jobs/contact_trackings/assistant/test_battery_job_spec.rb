# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::TestBatteryJob do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:job) { described_class.new }

  # Con la caché prendida (como en sus hilos) el sondeo nunca veía la respuesta y esperaba WAIT_SECONDS por mensaje.
  it 'deja de esperar en cuanto el agente contesta, aunque la caché de consultas esté prendida' do
    stub_const("#{described_class}::QUIET_SECONDS", 0)
    stub_const("#{described_class}::WAIT_SECONDS", 1)
    first = create(:message, account: account, inbox: conversation.inbox, conversation: conversation, message_type: :incoming)
    calls = 0
    allow(job).to receive(:sleep) do
      calls += 1
      if calls == 2
        # La escribe «otro proceso»: no vacía la caché de esta conexión.
        connection = ActiveRecord::Base.connection
        allow(connection).to receive(:clear_query_cache)
        create(:message, account: account, inbox: conversation.inbox, conversation: conversation, message_type: :outgoing,
                         content: 'Listo, el martes')
      end
    end

    reply = ActiveRecord::Base.cache { job.send(:wait_reply, conversation, first.id) }
    expect(reply).to eq('Listo, el martes')
    expect(calls).to be <= 3
  end
end
