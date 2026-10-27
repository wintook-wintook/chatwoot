# frozen_string_literal: true

require 'rails_helper'

# prospeccion P2b (docs/prospeccion_estudio.md §10.9) — el vendedor entró: la IA se calla.
RSpec.describe TrackingCampaigns::HandoffAttention do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:seller) { create(:user, account: account, role: :agent, name: 'Ana') }
  let(:inbox) { create(:inbox, account: account) }
  let(:board) { create(:kanban_type_process, account: account) }
  let(:hot) { create(:kanban_process, kanban_type_process: board) }
  let(:won) { create(:kanban_process, kanban_type_process: board) }
  let(:campaign) do
    create(:tracking_campaign, account: account, inbox: inbox, purpose: 'prospecting', daily_cap: 30,
                               handoff_board: board, handoff_column: hot)
  end
  let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: seller) }
  let!(:tracking) do
    create(:contact_tracking, account: account, inbox: inbox, contact: conversation.contact, conversation: conversation,
                              tracking_campaign: campaign, status: 'active', prospect_stage: 'handed_off',
                              handed_off_at: 1.hour.ago, handoff_due_at: 3.hours.from_now)
  end

  def reply(attributes = {})
    create(:message, { account: account, inbox: inbox, conversation: conversation, message_type: :outgoing,
                       sender: seller, content: 'Hola, soy Ana' }.merge(attributes))
  end

  it 'el vendedor escribió: atendido, el seguimiento cumple su objetivo y queda nota' do
    reply

    expect(described_class.check(tracking)).to be(true)
    expect(tracking.reload).to have_attributes(status: 'objective_met')
    expect(tracking.handoff_attended_at).to be_present
    expect(described_class.seller_owns?(conversation)).to be(true)
    expect(conversation.messages.activity.last.content).to start_with('🤝 Ana')
  end

  it 'sin nadie del equipo todavía: sigue pendiente y la IA sigue' do
    reply(content_attributes: { sentiment_auto_reply: true })

    expect(described_class.check(tracking)).to be(false)
    expect(tracking.reload.status).to eq('active')
    expect(described_class.seller_owns?(conversation)).to be(false)
  end

  describe 'se revisa al momento' do
    it 'un mensaje del vendedor encola la revisión unos segundos después' do
      expect { reply }.to have_enqueued_job(TrackingCampaigns::HandoffAttendedJob).with(conversation.id)
    end

    it 'una nota privada no la encola' do
      expect { reply(private: true) }.not_to have_enqueued_job(TrackingCampaigns::HandoffAttendedJob)
    end

    it 'mover la tarjeta a mano la encola y la marca atendida' do
      perform_enqueued_jobs(only: TrackingCampaigns::HandoffAttendedJob) do
        Kanban::FunnelMover.new(conversation).move!(board, won, source: 'manual', reason: 'avanzó', user_id: seller.id)
      end

      expect(tracking.reload.handoff_attended_at).to be_present
    end

    it 'sin interesado entregado en la conversación no encola nada' do
      tracking.update_columns(handoff_attended_at: Time.current) # rubocop:disable Rails/SkipsModelValidations

      expect { reply }.not_to have_enqueued_job(TrackingCampaigns::HandoffAttendedJob)
    end
  end

  it 'ya atendido: el analizador no contesta ni escala a BotSeller' do
    tracking.update_columns(handoff_attended_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    incoming = create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming,
                                sender: conversation.contact, content: '¿Y el precio?')
    job = ContactTrackingResponseAnalyzerJob.new
    allow(job).to receive(:process_message_for_tracking)

    job.perform(incoming.id)

    expect(job).not_to have_received(:process_message_for_tracking)
  end
end
