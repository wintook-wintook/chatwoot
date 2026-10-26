# frozen_string_literal: true

require 'rails_helper'

RSpec.describe KanbanFunnelListener do
  let(:listener) { described_class.instance }
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent) { create(:user, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:board) { create(:kanban_type_process, account: account).tap { |b| Kanban::FunnelTemplate.new(b).apply! } }
  let(:columns) { board.kanban_processes.by_position.to_a }

  before { conversation.update!(kanban_type_process_id: board.id, kanban_process_id: columns[0].id) }

  it 'la primera respuesta de un agente la pasa a «En contacto»; la segunda ya no cuenta' do
    message = create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing, sender: agent)
    listener.message_created(Events::Base.new('message.created', Time.zone.now, message: message))
    expect(conversation.reload.kanban_process_id).to eq(columns[1].id)

    conversation.update!(kanban_process_id: columns[0].id)
    again = create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing, sender: agent)
    listener.message_created(Events::Base.new('message.created', Time.zone.now, message: again))
    expect(conversation.reload.kanban_process_id).to eq(columns[0].id)
  end

  it 'una nota privada o un mensaje del cliente no es respuesta' do
    note = create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing,
                            sender: agent, private: true)
    listener.message_created(Events::Base.new('message.created', Time.zone.now, message: note))
    incoming = create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :incoming)
    listener.message_created(Events::Base.new('message.created', Time.zone.now, message: incoming))

    expect(conversation.reload.kanban_process_id).to eq(columns[0].id)
  end

  it 'agregar la etiqueta la mueve' do
    event = Events::Base.new('conversation.updated', Time.zone.now,
                             conversation: conversation, changed_attributes: { label_list: [[], ['interesado']] })
    listener.conversation_updated(event)

    expect(conversation.reload.kanban_process_id).to eq(columns[2].id)
  end
end
