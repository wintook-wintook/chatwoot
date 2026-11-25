# frozen_string_literal: true

require 'rails_helper'

# Campaña con IA · Encuesta (preguntas con tipo, baja por pregunta, NPS) y los filtros de audiencia de Reactivar,
# Recordar y Encuesta.
RSpec.describe TrackingCampaigns::SurveyItems do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }

  it 'guarda hasta 5 preguntas con su tipo, arma el texto con su rango y la baja de cada una' do
    brief = TrackingCampaigns::Motor2Brief.brief(
      'kind' => 'survey',
      'survey_items' => [{ 'text' => '¿Nos recomiendas?', 'type' => 'scale10' }, { 'text' => '¿Cómo te atendimos?', 'type' => 'scale5', 'low' => 4 },
                         { 'text' => '¿Qué mejoramos?', 'type' => 'open' }, { 'text' => '' }],
      'low_case' => { 'user_id' => admin.id, 'priority' => 'urgent' }
    )
    expect(brief['survey_questions']).to eq(['¿Nos recomiendas? (del 0 al 10)', '¿Cómo te atendimos? (del 1 al 5)', '¿Qué mejoramos?'])
    expect(brief['survey_items'].pluck('low')).to eq([7, 4, nil])
    expect(brief['low_case']).to include('user_id' => admin.id, 'priority' => 'urgent')
    expect(TrackingCampaigns::SurveyLink.range(brief['survey_questions'][1])).to eq(1..5)

    items = brief['survey_items']
    expect(described_class.low?(items, 1, 6, 7)).to be(true)
    expect(described_class.low?(items, 2, 4, 7)).to be(false)
    expect(described_class.low?(items, 3, nil, 7)).to be(false)
  end

  it 'el NPS sale de la pregunta de 0 a 10 y los comentarios de las abiertas' do
    items = [{ 'text' => 'Recomiendas', 'type' => 'scale10', 'low' => 7 }, { 'text' => 'Mejoras', 'type' => 'open' }]
    campaign = account.tracking_campaigns.create!(name: 'Encuesta', engine: '2', status: 'running', user: admin, scheduled_for: 1.day.ago,
                                                  brief: { 'kind' => 'survey', 'survey_items' => items }, touches: { 'attempts' => 1 })
    inbox = create(:channel_email, account: account).inbox
    [[10, 'Todo bien'], [9, ''], [3, 'Tardaron mucho']].each do |score, comment|
      contact = create(:contact, account: account)
      ContactTracking.create!(account: account, contact: contact, inbox: inbox, tracking_campaign: campaign, scheduled_for: 1.minute.from_now,
                              status: 'completed', max_attempts: 1, objective: 'Encuesta',
                              motor2_state: { 'survey' => { '1' => { 'calificacion' => score }, '2' => { 'respuesta' => comment } } })
    end
    result = TrackingCampaigns::SurveyResults.new(campaign, campaign.contact_trackings).call
    expect(result[:nps]).to include(score: 33, promoters: 2, detractors: 1)
    expect(result[:low]).to eq(1)
    expect(result[:comments].pluck(:answer)).to contain_exactly('Todo bien', 'Tardaron mucho')
  end

  describe 'filtros de audiencia' do
    let(:type) { account.contract_types.create!(name: 'Pólizas') }

    def count(key, value)
      payload = [{ 'attribute_key' => key, 'filter_operator' => 'equal_to', 'values' => [value], 'query_operator' => nil }]
      Contacts::FilterService.new(account, admin, { payload: payload }.with_indifferent_access).perform[:count]
    end

    it 'sin comprar desde N días, contrato por vencer y atendidos hace poco' do
      old = create(:contact, account: account)
      account.contracts.create!(contact: old, contract_type: type, title: 'Póliza vieja', price: 100, starts_on: 1.year.ago.to_date,
                                status: :cancelled)
      due = create(:contact, account: account)
      account.contracts.create!(contact: due, contract_type: type, title: 'Póliza', price: 100, starts_on: 2.months.ago.to_date,
                                next_charge_on: 10.days.from_now.to_date)

      expect(count('inactive_customer', '180:any')).to eq(1)
      expect(count('inactive_customer', '400:any')).to eq(0)
      expect(count('contract_due', '15:any')).to eq(1)
      expect(count('contract_due', "15:#{type.id + 999}")).to eq(0)
      expect(count('served_recently', '30')).to eq(0)
    end
  end
end
