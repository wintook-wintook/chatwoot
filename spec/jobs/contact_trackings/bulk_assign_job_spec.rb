# frozen_string_literal: true

require 'rails_helper'

# proyecto@automatizacion_campanas — Fase 2: el lote se inscribe por tandas con cursor.
RSpec.describe ContactTrackings::BulkAssignJob do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:template) { create(:tracking_template, account: account, inbox_id: inbox.id) }
  let(:campaign) do
    create(:tracking_campaign, account: account, inbox: inbox, tracking_template: template, scheduled_for: 1.hour.ago,
                               respect_working_hours: false)
  end
  let!(:contacts) { Array.new(3) { create(:contact, account: account, phone_number: "+52155#{rand(10_000_000..99_999_999)}") } }
  let(:args) do
    { account_id: account.id, current_user_id: nil, filter_payload: [], template_id: template.id,
      scheduled_for: 1.hour.ago.iso8601, excluded_contact_ids: [], skip_active: true, campaign_id: campaign.id }
  end

  before do
    stub_const('ContactTrackings::BulkAssignService::BATCH_SIZE', 2)
    allow_any_instance_of(ContactTrackings::BulkAssignService).to receive(:resolve_contacts) { account.contacts } # rubocop:disable RSpec/AnyInstance
  end

  it 'procesa una tanda y encola la siguiente desde el último contacto; la última no encola más' do
    expect { described_class.perform_now(args) }
      .to have_enqueued_job(described_class).with(hash_including(after_id: contacts[1].id))
    expect(campaign.entries.enrolled.count).to eq(2)

    expect { described_class.perform_now(args.merge(after_id: contacts[1].id)) }.not_to have_enqueued_job(described_class)
    expect(campaign.entries.enrolled.pluck(:contact_id)).to match_array(contacts.map(&:id))
  end
end
