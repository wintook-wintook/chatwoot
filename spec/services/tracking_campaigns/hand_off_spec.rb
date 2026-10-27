# frozen_string_literal: true

require 'rails_helper'

# prospeccion P2 (docs/prospeccion_estudio.md §10.9) — entregar al interesado.
RSpec.describe TrackingCampaigns::HandOff do
  let(:account) { create(:account) }
  let(:seller) { create(:user, account: account, role: :agent, name: 'Ana López') }
  let(:inbox) { create(:inbox, account: account, timezone: 'America/Mexico_City', working_hours_enabled: false) }
  let(:board) { create(:kanban_type_process, account: account) }
  let(:entry) { create(:kanban_process, kanban_type_process: board) }
  let(:hot) { create(:kanban_process, kanban_type_process: board) }
  let(:template) { create(:tracking_template, account: account, inbox_id: inbox.id) }
  let(:campaign) do
    create(:tracking_campaign, account: account, inbox: inbox, tracking_template: template, purpose: 'prospecting', daily_cap: 30,
                               user: seller, handoff_board: board, handoff_column: hot, handoff_due_hours: 4)
  end
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, assignee: nil) }
  let(:tracking) do
    create(:contact_tracking, account: account, inbox: inbox, contact: contact, conversation: conversation,
                              tracking_campaign: campaign, status: 'active', prospect_stage: 'interested')
  end

  before { create(:inbox_member, inbox: inbox, user: seller) }

  it 'entra a la columna de Oportunidades, se le asigna al vendedor, arranca el reloj y le avisa' do
    travel_to ActiveSupport::TimeZone['America/Mexico_City'].local(2026, 10, 5, 10) do
      expect(described_class.new(tracking).call).to be(true)

      expect(conversation.reload).to have_attributes(kanban_type_process_id: board.id, kanban_process_id: hot.id, assignee_id: seller.id)
      expect(tracking.reload).to have_attributes(prospect_stage: 'handed_off', handed_off_at: Time.current)
      expect(tracking.handoff_due_at).to eq(4.hours.from_now)
      expect(tracking.handoff_escalate_at).to be_nil

      note = conversation.messages.where(private: true).last
      expect(note.content).to include("mention://user/#{seller.id}/Ana%20L%C3%B3pez").and include(campaign.name)
      expect(KanbanMove.last).to have_attributes(source: 'automation', to_process_id: hot.id)
    end
  end

  it 'si la conversación ya tiene asignado, ese es el vendedor' do
    other = create(:user, account: account, role: :agent)
    conversation.update!(assignee: other)

    described_class.new(tracking).call

    expect(conversation.reload.assignee_id).to eq(other.id)
    expect(conversation.messages.where(private: true).last.content).to include("mention://user/#{other.id}/")
  end

  it 'con el botón: el movimiento queda a nombre de quien entregó' do
    described_class.new(tracking, user: seller).call

    expect(KanbanMove.last).to have_attributes(source: 'manual', user_id: seller.id)
  end

  it 'sin tablero en la campaña: se marca entregado pero no se mueve a Oportunidades' do
    campaign.update!(handoff_board: nil, handoff_column: nil)

    expect(described_class.new(tracking).call).to be(true)
    expect(conversation.reload.kanban_process_id).to be_nil
  end

  it 'solo entrega a un interesado, y una sola vez' do
    tracking.update!(prospect_stage: 'replied')
    expect(described_class.new(tracking).call).to be(false)

    tracking.update!(prospect_stage: 'interested')
    described_class.new(tracking).call
    expect(described_class.new(tracking.reload).call).to be(false)
  end

  describe 'la campaña' do
    it 'la columna tiene que ser del tablero elegido' do
      other_board = create(:kanban_type_process, account: account)
      campaign.handoff_column = create(:kanban_process, kanban_type_process: other_board)

      expect(campaign).not_to be_valid
      expect(campaign.errors[:handoff_column_id]).to be_present
    end

    it 'plazo y escalar van de 1 a 720 horas' do
      campaign.handoff_due_hours = 0
      expect(campaign).not_to be_valid
    end
  end
end
