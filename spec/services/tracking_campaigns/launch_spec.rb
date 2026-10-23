# frozen_string_literal: true

require 'rails_helper'

# proyecto@automatizacion_campanas — campaña Guardada que se pone en curso a mano.
RSpec.describe TrackingCampaigns::Launch do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:template) { create(:tracking_template, account: account, inbox_id: inbox.id) }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:contacts) { create_list(:contact, 2, account: account) }

  def saved_campaign(**attrs)
    create(:tracking_campaign, { account: account, inbox: inbox, tracking_template: template, status: 'saved',
                                 mode: 'batch', scheduled_for: 1.hour.ago,
                                 audience: { filter_payload: [], excluded_contact_ids: [], skip_active: true } }.merge(attrs))
  end

  # La audiencia por lote sale de Contacts::FilterService: aquí, los contactos del momento.
  before do
    allow_any_instance_of(ContactTrackings::BulkAssignService) # rubocop:disable RSpec/AnyInstance
      .to receive(:resolve_contacts).and_return(Contact.where(id: contacts.map(&:id)))
  end

  it 'por lote: abre la campaña ANTES de encolar la inscripción y corre a ahora un inicio ya pasado' do
    campaign = saved_campaign
    expect(ContactTrackings::BulkAssignJob).to receive(:perform_later) do |args|
      expect(campaign.reload.status).to eq('running')
      expect(args[:campaign_id]).to eq(campaign.id)
    end

    result = described_class.new(campaign, user).call

    expect(result).to include(queued: 2)
    expect(campaign.reload.scheduled_for).to be_within(5.seconds).of(Time.current)
  end

  it 'respeta un inicio futuro: queda Programada' do
    start = 2.days.from_now.change(usec: 0)
    campaign = saved_campaign(scheduled_for: start)
    allow(ContactTrackings::BulkAssignJob).to receive(:perform_later)

    described_class.new(campaign, user).call

    expect(campaign.reload).to have_attributes(status: 'draft', scheduled_for: start)
  end

  it 'sin contactos en la audiencia no la abre ni encola nada' do
    campaign = saved_campaign
    allow_any_instance_of(ContactTrackings::BulkAssignService) # rubocop:disable RSpec/AnyInstance
      .to receive(:resolve_contacts).and_return(Contact.none)
    expect(ContactTrackings::BulkAssignJob).not_to receive(:perform_later)

    expect(described_class.new(campaign, user).call).to eq(error: 'La selección no tiene contactos.')
    expect(campaign.reload.status).to eq('saved')
  end

  it 'continua: solo cambia el estado y desde ahí acepta inscripciones' do
    campaign = saved_campaign(mode: 'continuous')
    expect(campaign.accepting_entries?).to be(false)
    expect(ContactTrackings::BulkAssignJob).not_to receive(:perform_later)

    described_class.new(campaign, user).call

    expect(campaign.reload.status).to eq('running')
    expect(campaign.accepting_entries?).to be(true)
  end

  it 'Guardar por lote (launch: false) crea la campaña Guardada con su audiencia y no encola nada' do
    expect(ContactTrackings::BulkAssignJob).not_to receive(:perform_later)

    result = ContactTrackings::BulkAssignService.new(
      account: account, current_user: user, filter_payload: [{ 'attribute_key' => 'name' }], template_id: template.id,
      scheduled_for: 1.day.from_now, campaign_name: 'Lote', excluded_contact_ids: [7], skip_active: false, launch: false
    ).call

    campaign = TrackingCampaign.find(result[:campaign_id])
    expect(result).to include(saved: true, contacts: 2)
    expect(campaign).to have_attributes(status: 'saved', mode: 'batch')
    expect(campaign.audience).to include('excluded_contact_ids' => [7], 'skip_active' => false)
  end

  it 'no relanza una campaña que ya no está Guardada ni una con la ventana vencida' do
    expect(described_class.new(saved_campaign(status: 'running'), user).call).to include(:error)
    expect(described_class.new(saved_campaign(ends_at: 1.minute.ago, scheduled_for: 1.hour.ago), user).call)
      .to include(:error)
  end
end
