# frozen_string_literal: true

require 'rails_helper'

# Campaña con IA · Recordar — cada contrato entra cuando le toca, con sus toques en fechas según SU vencimiento, ligado
# a su contrato (lo que le vence), y «ya pagué» deja una tarea para verificarlo.
RSpec.describe TrackingCampaigns::RenewEnroll do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:channel_email, account: account).inbox }
  let(:seller) { Motor2::Functions::Form.new(account, { kind: 'campaign_seller', name: 'Vendedor', enabled: true, settings: {} }, user: admin).save }
  let(:type) { account.contract_types.create!(name: 'Pólizas') }
  let(:contact) { create(:contact, account: account, name: 'Mario López', email: 'mario@ejemplo.com') }
  let!(:contract) do
    account.contracts.create!(contact: contact, contract_type: type, title: 'Póliza anual', price: 1800, starts_on: 1.year.ago.to_date,
                              next_charge_on: 5.days.from_now.to_date, assignee: admin)
  end
  let(:campaign) do
    brief = TrackingCampaigns::Motor2Brief.brief('kind' => 'renew', 'offer_goal' => 'done',
                                                 'renew_source' => { 'contract_type_id' => type.id, 'offsets' => %w[1 7 0 99] })
    account.tracking_campaigns.create!(name: 'Renovaciones', engine: '2', status: 'running', mode: 'continuous', tracking_template: seller,
                                       inbox: inbox, user: admin, scheduled_for: 1.day.ago, brief: brief, touches: { 'attempts' => 3 })
  end

  it 'guarda los días ordenados y queda continua' do
    expect(campaign.brief['renew_source']).to eq('contract_type_id' => type.id, 'offsets' => [7, 1, 0])
    saved = TrackingCampaigns::Motor2Form.new(account, admin,
                                              { name: 'Renovaciones', brief: { kind: 'renew', renew_source: { offsets: [3] } } }).save[:campaign]
    expect(saved.mode).to eq('continuous')
  end

  it 'entra con sus toques en las fechas que faltan, ligado a su contrato; no entra dos veces' do
    expect(described_class.new(campaign).call).to eq(1)
    tracking = campaign.contact_trackings.last
    due = contract.next_charge_on
    expect(tracking.contract_id).to eq(contract.id)
    # 7 días antes ya pasó: quedan 1 día antes y el día (si el horario de la bandeja movió el primero al día, solo ese)
    expect(tracking.scheduled_for.to_date).to be_between(due - 1, due)
    expect(tracking.max_attempts).to eq(1 + tracking.motor2_state['schedule'].size)
    if tracking.motor2_state['schedule'].any?
      tracking.update_columns(attempt_count: 1) # rubocop:disable Rails/SkipsModelValidations
      expect(tracking.reload.next_scheduled_time.to_date).to eq(due)
    end
    expect(described_class.new(campaign).call).to eq(0)
  end

  it 'lo que le vence sale de SU contrato y «ya pagué» deja una tarea al responsable' do
    account.contracts.create!(contact: contact, contract_type: type, title: 'Otra póliza', price: 50, starts_on: 1.month.ago.to_date,
                              next_charge_on: 2.days.from_now.to_date)
    described_class.new(campaign).call
    tracking = campaign.contact_trackings.last
    expect(TrackingCampaigns::ContactFacts.new(contact).values['due_what']).to eq(tracking.contract.title)

    subject = TrackingCampaigns::EmailSubject.render('{{contacto}}, tu {{que_vence}} vence el {{vence}}', contact, campaign)
    expect(subject).to start_with("Mario, tu #{tracking.contract.title} vence el ")

    function = Motor2::Config.new(seller.reload, answers: TrackingCampaigns::Motor2Brief.seller_answers(campaign)).function
    conversation = create(:conversation, account: account, inbox: inbox, contact: contact)
    Motor2::Functions::CampaignSellerOutcomes.new(tracking, conversation, function).apply('achieved', 'Ya pagué')
    task = CaseTask.where(contact: contact).last
    expect(task).to have_attributes(assignee_id: tracking.contract.assignee_id || admin.id)
    expect(task.title).to start_with('Verificar pago')
  end
end
