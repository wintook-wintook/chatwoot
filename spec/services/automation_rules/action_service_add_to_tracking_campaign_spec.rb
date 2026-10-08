# frozen_string_literal: true

require 'rails_helper'

# proyecto@automatizacion_campanas — F2: la acción "Agregar a campaña"
# (docs/automatizacion_campanas_plan.md §4).
RSpec.describe AutomationRules::ActionService, '#add_to_tracking_campaign' do
  let(:account) { create(:account) }
  let(:campaign_inbox) { create(:inbox, account: account) }
  let(:other_inbox) { create(:inbox, account: account) }
  let(:template) do
    create(:tracking_template, account: account, inbox_id: campaign_inbox.id, retry_interval_value: 2,
                               retry_interval_unit: 'hours')
  end
  let(:campaign) do
    create(:tracking_campaign, account: account, inbox: campaign_inbox, tracking_template: template, mode: 'continuous',
                               scheduled_for: 1.hour.ago, respect_working_hours: false)
  end
  let(:contact) { create(:contact, account: account) }
  let(:rule) do
    create(:automation_rule, account: account, name: 'Etiqueta demo', event_name: 'conversation_created',
                             actions: [{ 'action_name' => 'add_to_tracking_campaign', 'action_params' => [campaign.id] }])
  end

  before { create(:user, account: account, role: :administrator) }

  def run(conversation)
    AutomationRules::ActionService.new(rule, account, conversation).perform
  end

  it 'la regla acepta la acción' do
    expect(rule).to be_valid
  end

  it 'desde otro inbox: inscribe y el agente escribe por el inbox de la campaña, a la hora de la ventana' do
    conversation = create(:conversation, account: account, inbox: other_inbox, contact: contact)
    run(conversation)

    entry = campaign.entries.last
    expect(entry).to have_attributes(status: 'enrolled', source: 'automation', automation_rule_id: rule.id,
                                     conversation_id: conversation.id)
    tracking = entry.contact_tracking
    expect(tracking.inbox_id).to eq(campaign_inbox.id)
    expect(tracking.conversation_id).not_to eq(conversation.id)
    expect(tracking.scheduled_for).to be_within(5.seconds).of(Time.current)
  end

  # Mismo inbox: el cliente ya está escribiendo y el analizador le contesta; un primer
  # mensaje proactivo "ya" saldría doble (lo mismo que resuelve "Asignar Agente IA").
  it 'desde el inbox de la campaña: usa esa conversación y corre el primer mensaje al intervalo de la plantilla' do
    conversation = create(:conversation, account: account, inbox: campaign_inbox, contact: contact)
    run(conversation)

    tracking = campaign.entries.last.contact_tracking
    expect(tracking.conversation_id).to eq(conversation.id)
    expect(tracking.scheduled_for).to be_within(5.seconds).of(2.hours.from_now)
  end

  it 'una campaña borrada no rompe la regla ni inscribe' do
    conversation = create(:conversation, account: account, inbox: other_inbox, contact: contact)
    campaign_id = campaign.id
    rule
    campaign.destroy!

    expect { run(conversation) }.not_to raise_error
    expect(TrackingCampaignEntry.where(tracking_campaign_id: campaign_id)).to be_empty
  end

  it 'el analizador espera a la automatización que va a crear el seguimiento' do
    rule.update!(event_name: 'message_created', conditions: [])
    conversation = create(:conversation, account: account, inbox: other_inbox, contact: contact)
    message = build(:message, account: account, inbox: other_inbox, conversation: conversation, message_type: :incoming)

    expect(message.send(:will_trigger_tracking_automation?)).to be(true)
  end

  describe 'GET tracking_campaigns?lite=true', type: :request do
    let(:agent) { create(:user, account: account, role: :agent) }

    it 'devuelve solo lo que necesita el selector' do
      campaign.update!(ends_at: 30.days.from_now)

      get "/api/v1/accounts/#{account.id}/tracking_campaigns", params: { lite: true },
                                                               headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.first.keys).to match_array(%w[id name status mode scheduled_for ends_at inbox_id])
      expect(response.parsed_body.first['mode']).to eq('continuous')
    end
  end
end
