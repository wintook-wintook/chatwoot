# frozen_string_literal: true

require 'rails_helper'

# proyecto@automatizacion_campanas — pausa por error de configuración de Meta y reanudación
RSpec.describe TrackingCampaigns::Resume do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:campaign) { create(:tracking_campaign, account: account, inbox: inbox, scheduled_for: 1.hour.ago) }

  def tracking(**attributes)
    create(:contact_tracking, account: account, inbox: inbox, contact: create(:contact, account: account),
                              tracking_campaign: campaign, **attributes)
  end

  before { TrackingCampaigns::Pause.new(campaign, reason: 'Meta 132001: template does not exist').perform }

  it 'la pausa deja la campaña sin aceptar inscripciones y conserva el primer motivo' do
    TrackingCampaigns::Pause.new(campaign, reason: 'otro motivo').perform

    expect(campaign.reload).to have_attributes(status: 'paused', paused_reason: 'Meta 132001: template does not exist')
    expect(campaign.accepting_entries?).to be(false)
  end

  it 'vuelve a En curso y reanuda solo los seguimientos que pausó la campaña' do
    by_campaign = tracking(status: 'paused', paused_by_campaign: true)
    by_hand = tracking(status: 'paused')
    # cancel_existing_jobs recorre Redis real (la BD de pruebas es la del servidor): no se toca.
    allow_any_instance_of(ContactTracking).to receive(:cancel_existing_jobs) # rubocop:disable RSpec/AnyInstance

    result = described_class.new(campaign).call
    expect(result[:trackings]).to eq(1)
    expect(campaign.reload).to have_attributes(status: 'running', paused_reason: nil)

    perform_enqueued_jobs(only: TrackingCampaigns::ResumeJob)
    expect(by_campaign.reload).to have_attributes(status: 'scheduled', paused_by_campaign: false)
    expect(by_campaign.scheduled_for).to be_within(5.seconds).of(1.minute.from_now)
    expect(by_hand.reload.status).to eq('paused')
  end

  it 'si la ventana terminó mientras estaba pausada, queda Finalizada' do
    campaign.update_columns(ends_at: 1.minute.ago) # rubocop:disable Rails/SkipsModelValidations

    described_class.new(campaign).call
    expect(campaign.reload.status).to eq('finished')
  end

  it 'una campaña que no está pausada no se reanuda' do
    campaign.update_columns(status: 'running') # rubocop:disable Rails/SkipsModelValidations

    expect(described_class.new(campaign).call).to eq(error: 'La campaña no está pausada.')
  end

  describe ContactTrackingJob do
    it 'un seguimiento de una campaña pausada se pausa al llegar su turno, sin enviar' do
      due = tracking(status: 'scheduled').tap { |t| t.update_column(:scheduled_for, 1.minute.ago) } # rubocop:disable Rails/SkipsModelValidations

      expect { described_class.perform_now(due.id) }.not_to change(Message, :count)
      expect(due.reload).to have_attributes(status: 'paused', paused_by_campaign: true)
    end
  end
end
