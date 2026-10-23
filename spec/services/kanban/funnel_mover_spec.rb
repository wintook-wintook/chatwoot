# frozen_string_literal: true

require 'rails_helper'

# Embudo de contactos E1 — la propia conversación mueve su tarjeta.
RSpec.describe Kanban::FunnelMover do
  let(:account) { create(:account, locale: 'es') }
  let(:inbox) { create(:inbox, account: account) }
  let(:other_inbox) { create(:inbox, account: account) }
  let!(:board) do
    create(:kanban_type_process, account: account).tap do |b|
      Kanban::FunnelTemplate.new(b).apply!
      b.update!(entry_inbox_ids: [inbox.id])
    end
  end
  let(:columns) { board.kanban_processes.by_position.index_by(&:type_process_name) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }

  def place(column)
    conversation.update!(kanban_type_process_id: board.id, kanban_process_id: column.id)
    conversation.reload
  end

  describe 'plantilla' do
    it 'nace con sus columnas, reglas y el movimiento automático encendido' do
      expect(board.auto_move).to be(true)
      expect(columns.keys).to eq(['Nuevo', 'En contacto', 'Interesado', 'Cita', 'Convertido', 'Descartado'])
      expect(columns['Convertido']).to be_stage_converted
      expect(columns['Interesado'].ai_criteria).to include('precio')
      expect(board.entry_column).to eq(columns['Nuevo'])
    end
  end

  describe '#enter!' do
    it 'mete a «Nuevo» una conversación nueva de una bandeja del tablero y deja nota' do
      described_class.new(conversation).enter!

      expect(conversation.reload.kanban_process_id).to eq(columns['Nuevo'].id)
      expect(conversation.kanban_move_source).to eq('rule')
      expect(conversation.messages.activity.last.content).to include('Nuevo')
    end

    it 'no toca conversaciones de otras bandejas ni las que ya están en un tablero' do
      foreign = create(:conversation, account: account, inbox: other_inbox)
      described_class.new(foreign).enter!
      expect(foreign.reload.kanban_type_process_id).to be_nil

      place(columns['Cita'])
      described_class.new(conversation).enter!
      expect(conversation.reload.kanban_process_id).to eq(columns['Cita'].id)
    end
  end

  describe '#trigger!' do
    it 'avanza con la primera respuesta y con la etiqueta' do
      place(columns['Nuevo'])
      described_class.new(conversation).trigger!(:first_reply)
      expect(conversation.reload.kanban_process_id).to eq(columns['En contacto'].id)

      described_class.new(conversation).trigger!(:label_added, labels: %w[otra interesado])
      expect(conversation.reload.kanban_process_id).to eq(columns['Interesado'].id)
      expect(conversation.kanban_move_reason).to include('interesado')
    end

    it 'nunca regresa una tarjeta (mover a mano gana)' do
      place(columns['Cita'])
      described_class.new(conversation).trigger!(:first_reply)

      expect(conversation.reload.kanban_process_id).to eq(columns['Cita'].id)
    end

    it 'una tarjeta convertida o descartada ya no se mueve' do
      columns['Descartado'].update!(position: 2)
      place(columns['Descartado'])
      described_class.new(conversation).trigger!(:appointment_scheduled)

      expect(conversation.reload.kanban_process_id).to eq(columns['Descartado'].id)
    end

    it 'solo convierte con un caso de la clase configurada' do
      place(columns['Interesado'])
      described_class.new(conversation).trigger!(:case_created, case_class: 'support', folio: 'S-1')
      expect(conversation.reload.kanban_process_id).to eq(columns['Interesado'].id)

      described_class.new(conversation).trigger!(:case_created, case_class: 'commercial', folio: 'V-7')
      expect(conversation.reload.kanban_process_id).to eq(columns['Convertido'].id)
      expect(conversation.kanban_move_reason).to include('V-7')
    end
  end

  describe 'hechos que nacen fuera de la conversación' do
    include ActiveJob::TestHelper

    it 'un caso comercial ligado a la conversación la pasa a «Convertido»' do
      place(columns['En contacto'])
      venta = CaseType.create!(account: account, name: 'Venta', color: '#8b5cf6', case_class: :commercial)
      contact = create(:contact, account: account)

      perform_enqueued_jobs(only: Kanban::FunnelTriggerJob) do
        CaseTicket.create!(account: account, title: 'Licencias', contact: contact, case_type: venta, conversation: conversation)
      end

      expect(conversation.reload.kanban_process_id).to eq(columns['Convertido'].id)
      expect(KanbanMove.where(conversation: conversation).pluck(:source)).to include('rule')
    end
  end
end
