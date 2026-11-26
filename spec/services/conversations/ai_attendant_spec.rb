# frozen_string_literal: true

require 'rails_helper'

# «Agente IA» en las conversaciones: quién la atiende (aparte del responsable), el filtro de la lista y sus conteos, la
# conversación de campaña que nace sin responsable (sin asignación automática) y se resuelve sola si la IA termina sin
# entregarla.
RSpec.describe Conversations::AiAttendant do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator, name: 'Ana') }
  let(:inbox) { create(:inbox, account: account, enable_auto_assignment: true) }
  let(:seller) { Motor2::Functions::Form.new(account, { kind: 'campaign_seller', name: 'Vendedor', enabled: true, settings: {} }, user: admin).save }
  let(:campaign) do
    account.tracking_campaigns.create!(name: 'Expo Industrial', engine: '2', status: 'running', tracking_template: seller, inbox: inbox,
                                       user: admin, scheduled_for: 1.day.ago, brief: { 'kind' => 'invite' }, touches: { 'attempts' => 1 })
  end
  let(:contact) { create(:contact, account: account, name: 'Mario') }

  before { create(:inbox_member, inbox: inbox, user: admin) }

  # Un contacto por conversación (un solo seguimiento vivo por contacto y bandeja).
  def conversation(**attrs) = create(:conversation, account: account, inbox: inbox, contact: create(:contact, account: account), **attrs)

  def tracking(conv, status: 'scheduled', template: seller, campaign: self.campaign)
    ContactTracking.create!(account: account, contact: conv.contact, inbox: inbox, tracking_template: template, tracking_campaign: campaign,
                            conversation: conv, scheduled_for: 1.day.from_now, status: status, max_attempts: 1, objective: 'Invitar')
  end

  it 'dice qué agente atiende y lo filtra y cuenta, aparte del responsable' do
    with_ai = conversation(assignee: admin)
    tracking(with_ai)
    paused = conversation.tap { |c| tracking(c, status: 'paused') }
    plain = conversation
    only_ai = conversation.tap { |c| tracking(c) }
    person = conversation(assignee: admin)

    expect(described_class.for(with_ai)).to eq(function: 'campaign_seller', name: 'Expo Industrial')
    expect(described_class.for(paused)).to be_nil
    scope = account.conversations
    expect(described_class.filter(scope, 'with')).to contain_exactly(only_ai)
    expect(described_class.filter(scope, 'without')).to contain_exactly(with_ai, person)
    expect(described_class.filter(scope, 'campaign_seller')).to contain_exactly(with_ai, only_ai)
    expect(described_class.counts(scope)).to eq('campaign_seller' => 2)
    expect([paused, plain].map(&:assignee)).to all(be_nil)
  end

  it 'la lista de conversaciones acepta el filtro y trae los conteos por agente', type: :request do
    tracking(conversation)
    conversation
    get "/api/v1/accounts/#{account.id}/conversations", params: { assignee_type: 'all', ai_agent: 'with' },
                                                        headers: admin.create_new_auth_token, as: :json
    data = response.parsed_body['data']
    expect(data['payload'].size).to eq(1)
    expect(data['payload'].first['ai_agent']).to include('function' => 'campaign_seller')
    expect(data['meta']['ai_agents']).to eq('campaign_seller' => 1)
  end

  it 'la de campaña nace sin responsable y la asignación automática no se la da a nadie' do
    conv = TrackingCampaigns::TrackingBuilder.new(campaign, contact, agent: admin, note: 'Campaña').open_conversation
    expect(conv.assignee_id).to be_nil
    expect(conv.additional_attributes['ai_campaign']).to eq(campaign.id)
  end

  it 'al entregarla se asigna (o al dueño de la campaña si el destino es solo un equipo) y se quita la marca' do
    conv = conversation(additional_attributes: { 'ai_campaign' => campaign.id })
    Motor2::HandoffAssign.call(conv, {}, tracking: tracking(conv))
    expect(conv.reload).to have_attributes(assignee_id: admin.id)
    expect(conv.additional_attributes).not_to have_key('ai_campaign')
  end

  it 'si la IA termina sin entregarla y nadie la tiene, se resuelve sola; con responsable, no' do
    alone = conversation(status: :open)
    tracking(alone).update!(status: 'completed')
    expect(alone.reload.status).to eq('resolved')

    owned = conversation(status: :open, assignee: admin)
    tracking(owned).update!(status: 'completed')
    expect(owned.reload.status).to eq('open')
  end
end
