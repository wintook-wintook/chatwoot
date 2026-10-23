# frozen_string_literal: true

require 'rails_helper'

# Embudo de contactos E2 — IA, vencimientos, regreso del cliente, resolución sin caso
# y la columna «Convertir».
RSpec.describe 'Embudo de contactos E2' do
  include ActiveJob::TestHelper

  let(:account) { create(:account, locale: 'es') }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:board) { create(:kanban_type_process, account: account).tap { |b| Kanban::FunnelTemplate.new(b).apply! } }
  let(:columns) { board.kanban_processes.by_position.index_by(&:type_process_name) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: agent) }

  def place(column)
    conversation.update!(kanban_type_process_id: board.id, kanban_process_id: column.id)
    conversation.reload
  end

  def customer_says(text, at: Time.current)
    create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :incoming,
                     content: text, created_at: at)
  end

  describe Kanban::FunnelAi do
    before do
      board.update!(ai_move: true)
      place(columns['En contacto'])
      customer_says('¿Cuánto cuesta el plan anual? ¿Hay entrega esta semana?')
      allow_any_instance_of(described_class).to receive(:available?).and_return(true)
    end

    def ai_answers(answer)
      allow_any_instance_of(described_class).to receive(:chat).and_return(answer)
    end

    it 'segura: mueve la tarjeta y deja una nota privada con el porqué y el siguiente paso' do
      ai_answers('column_id' => columns['Interesado'].id, 'confidence' => 0.9,
                 'reason' => 'Pidió precio del plan anual', 'next_step' => 'Mandar cotización')

      expect(described_class.new(conversation).call).to eq(:moved)
      expect(conversation.reload.kanban_process_id).to eq(columns['Interesado'].id)
      expect(conversation.kanban_move_source).to eq('ai')
      note = conversation.messages.where(private: true).last
      expect(note.content).to include('Interesado', 'Pidió precio', 'Mandar cotización')
    end

    it 'con duda: no mueve, solo sugiere' do
      ai_answers('column_id' => columns['Interesado'].id, 'confidence' => 0.6, 'reason' => 'Tal vez')

      expect(described_class.new(conversation).call).to eq(:suggested)
      expect(conversation.reload.kanban_process_id).to eq(columns['En contacto'].id)
      expect(conversation.messages.where(private: true).last.content).to include('Podría pasar')
    end

    it 'nunca elige una columna hacia atrás ni la de convertir' do
      ai_answers('column_id' => columns['Convertido'].id, 'confidence' => 0.99, 'reason' => 'x')
      expect(described_class.new(conversation).call).to be_nil

      ai_answers('column_id' => columns['Nuevo'].id, 'confidence' => 0.99, 'reason' => 'x')
      expect(described_class.new(conversation).call).to be_nil
      expect(conversation.reload.kanban_process_id).to eq(columns['En contacto'].id)
    end

    it 'no corre si el embudo no tiene la IA encendida' do
      board.update!(ai_move: false)
      expect_any_instance_of(described_class).not_to receive(:chat)

      expect(described_class.new(conversation.reload).call).to be_nil
    end
  end

  describe Kanban::FunnelAiJob do
    it 'solo analiza el último mensaje de una ráfaga' do
      board.update!(ai_move: true)
      place(columns['En contacto'])
      first = customer_says('hola')
      customer_says('quiero precio')
      expect(Kanban::FunnelAi).not_to receive(:new)

      described_class.perform_now(conversation.id, first.id)
    end
  end

  describe 'regreso del cliente y resolución sin caso' do
    let(:listener) { KanbanFunnelListener.instance }

    it 'una tarjeta descartada regresa a la entrada cuando el cliente vuelve a escribir' do
      place(columns['Descartado'])
      message = customer_says('Siempre sí me interesa')

      listener.message_created(Events::Base.new('message.created', Time.zone.now, message: message))

      expect(conversation.reload.kanban_process_id).to eq(columns['Nuevo'].id)
      expect(conversation.kanban_move_reason).to include('volvió a escribir')
    end

    it 'resolver la conversación sin caso la descarta; con caso no' do
      place(columns['Interesado'])
      listener.conversation_resolved(Events::Base.new('conversation.resolved', Time.zone.now, conversation: conversation))
      expect(conversation.reload.kanban_process_id).to eq(columns['Descartado'].id)
    end

    it 'un caso creado saca la tarjeta de Descartado y la convierte' do
      place(columns['Descartado'])
      Kanban::FunnelMover.new(conversation).trigger!(:case_created, case_class: 'commercial', folio: 'V-1')

      expect(conversation.reload.kanban_process_id).to eq(columns['Convertido'].id)
    end
  end

  describe Kanban::FunnelStaleJob do
    it 'descarta las tarjetas abiertas sin respuesta del cliente en los días del embudo' do
      board.update!(discard_after_days: 5)
      place(columns['Interesado'])
      customer_says('luego te aviso', at: 8.days.ago)
      fresh = create(:conversation, account: account, inbox: inbox)
      fresh.update!(kanban_type_process_id: board.id, kanban_process_id: columns['Interesado'].id)
      create(:message, conversation: fresh, account: account, inbox: inbox, message_type: :incoming, content: 'hoy')

      described_class.perform_now

      expect(conversation.reload.kanban_process_id).to eq(columns['Descartado'].id)
      expect(conversation.kanban_move_reason).to include('5 días')
      expect(fresh.reload.kanban_process_id).to eq(columns['Interesado'].id)
    end
  end

  describe 'columna «Convertir»' do
    let(:venta) { CaseType.create!(account: account, name: 'Venta', color: '#8b5cf6', case_class: :commercial) }

    before do
      columns['Convertido'].update!(convert_case_type_id: venta.id)
      conversation.contact.update!(name: 'Ana')
      place(columns['Cita'])
    end

    it 'soltar la tarjeta a mano crea la oportunidad ligada a la conversación' do
      Current.user = agent
      conversation.update!(kanban_process_id: columns['Convertido'].id)

      ticket = conversation.case_tickets.last
      expect(ticket).to be_present
      expect(ticket.case_type).to eq(venta)
    ensure
      Current.reset
    end

    it 'no duplica si ya hay una oportunidad abierta, ni convierte por regla' do
      Current.user = agent
      CaseTicket.create!(account: account, title: 'Ya existe', contact: conversation.contact, case_type: venta,
                         conversation: conversation)
      conversation.update!(kanban_process_id: columns['Convertido'].id)
      expect(conversation.case_tickets.count).to eq(1)
    ensure
      Current.reset
    end
  end
end
