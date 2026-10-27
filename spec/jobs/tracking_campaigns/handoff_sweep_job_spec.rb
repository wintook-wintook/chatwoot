# frozen_string_literal: true

require 'rails_helper'

# prospeccion P2 (docs/prospeccion_estudio.md §10.9) — ¿ya atendieron al interesado?
RSpec.describe TrackingCampaigns::HandoffSweepJob do
  let(:account) { create(:account) }
  let(:seller) { create(:user, account: account, role: :agent) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account) }
  let(:board) { create(:kanban_type_process, account: account) }
  let(:hot) { create(:kanban_process, kanban_type_process: board) }
  let(:won) { create(:kanban_process, kanban_type_process: board) }
  let(:campaign) do
    create(:tracking_campaign, account: account, inbox: inbox, purpose: 'prospecting', daily_cap: 30,
                               handoff_board: board, handoff_column: hot)
  end
  let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: seller) }
  let(:handed_off_at) { 5.hours.ago }
  let!(:tracking) do
    create(:contact_tracking, account: account, inbox: inbox, contact: conversation.contact, conversation: conversation,
                              tracking_campaign: campaign, status: 'active', prospect_stage: 'handed_off',
                              handed_off_at: handed_off_at, handoff_due_at: 1.hour.ago, handoff_escalate_at: 1.hour.from_now)
  end

  before do
    admin
    create(:inbox_member, inbox: inbox, user: seller)
  end

  def reply(attributes = {})
    create(:message, { account: account, inbox: inbox, conversation: conversation, message_type: :outgoing,
                       sender: seller, content: 'Hola, te llamo en un momento' }.merge(attributes))
  end

  def notes
    conversation.messages.where(private: true).pluck(:content)
  end

  it 'una persona del equipo le escribió: atendido, sin recordatorio' do
    message = reply

    described_class.perform_now

    expect(tracking.reload.handoff_attended_at).to be_within(1.second).of(message.created_at)
    expect(notes).to be_empty
  end

  it 'lo que escribe la IA no cuenta (marcas de bot o toque del seguimiento)' do
    reply(content_attributes: { sentiment_auto_reply: true })
    touch = reply
    TrackingDelivery.create!(account: account, contact_tracking: tracking, kind: 'session', message: touch, status: 'sent',
                             attempt_number: 1, repetition: 1, retry_count: 0)

    described_class.perform_now

    expect(tracking.reload.handoff_attended_at).to be_nil
  end

  it 'mover la tarjeta a mano en Oportunidades también cuenta' do
    Kanban::FunnelMover.new(conversation).move!(board, won, source: 'manual', reason: 'avanzó', user_id: seller.id)

    described_class.perform_now

    expect(tracking.reload.handoff_attended_at).to be_present
  end

  it 'venció el plazo: recordatorio con mención al vendedor, una sola vez' do
    2.times { described_class.perform_now }

    expect(tracking.reload.handoff_reminded_at).to be_present
    expect(notes.size).to eq(1)
    expect(notes.first).to include('⏰').and include("mention://user/#{seller.id}/")
  end

  it 'venció escalar: aviso a los administradores' do
    tracking.update_columns(handoff_escalate_at: 1.minute.ago) # rubocop:disable Rails/SkipsModelValidations

    described_class.perform_now

    expect(tracking.reload.handoff_escalated_at).to be_present
    expect(notes.find { |note| note.include?('🚨') }).to include("mention://user/#{admin.id}/")
  end

  it 'sin plazo no recuerda nada' do
    tracking.update_columns(handoff_due_at: nil, handoff_escalate_at: nil) # rubocop:disable Rails/SkipsModelValidations

    described_class.perform_now

    expect(notes).to be_empty
  end
end
