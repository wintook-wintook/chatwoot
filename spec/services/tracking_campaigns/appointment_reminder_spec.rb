# frozen_string_literal: true

require 'rails_helper'

# Campaña con IA · Ofrecer y Reactivar con cita — el recordatorio de la cita: fijo o de la IA al momento, con su
# plantilla para después de 24 h; en otras campañas, nada (sigue el aviso del vendedor).
RSpec.describe TrackingCampaigns::AppointmentReminder do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator, name: 'Ana López') }
  let(:inbox) { create(:channel_email, account: account).inbox }
  let(:seller) { Motor2::Functions::Form.new(account, { kind: 'campaign_seller', name: 'Vendedor', enabled: true, settings: {} }, user: admin).save }
  let(:contact) { create(:contact, account: account, name: 'Mario Pérez', email: 'mario@ejemplo.com') }
  let(:at) { 2.days.from_now.change(hour: 10) }
  let(:meeting) do
    CaseMeeting.create!(account: account, contact: contact, title: 'Cita', starts_at: at, ends_at: at + 1.hour, organizer: admin)
  end

  def tracking(brief)
    camp = account.tracking_campaigns.create!(name: 'Promo', engine: '2', status: 'running', tracking_template: seller, inbox: inbox,
                                              user: admin, scheduled_for: 1.day.ago, brief: brief, touches: { 'attempts' => 1 })
    person = create(:contact, account: account, name: 'Mario Pérez') # un seguimiento vivo por contacto y bandeja
    ContactTracking.create!(account: account, contact: person, inbox: inbox, tracking_template: seller, tracking_campaign: camp,
                            scheduled_for: 1.minute.from_now, status: 'active', max_attempts: 1, objective: 'Agendar la cita')
  end

  it 'con cita: el mensaje fijo con sus datos y su plantilla' do
    trk = tracking({ 'kind' => 'offer', 'offer_goal' => 'appointment',
                     'appointment_reminder' => { 'ai' => false, 'text' => 'Hola {{nombre}}, te esperamos el {{cuando}} con {{con}}.',
                                                 'template' => 'cita_recordatorio' } })
    text = described_class.text_for(trk, meeting)
    expect(text).to start_with('Hola Mario, te esperamos el ').and end_with('con Ana.')
    expect(described_class.template(trk)).to eq('cita_recordatorio')
  end

  it 'sin texto, el de fábrica; sin cita o en otro tipo, nada' do
    trk = tracking({ 'kind' => 'reactivate', 'offer_goal' => 'appointment', 'appointment_reminder' => { 'ai' => false } })
    expect(described_class.text_for(trk, meeting)).to include('¡Hola Mario! Te recuerdo tu cita', 'con Ana')
    expect(described_class.text_for(tracking({ 'kind' => 'offer', 'offer_goal' => 'relay' }), meeting)).to be_nil
    expect(described_class.text_for(tracking({ 'kind' => 'invite' }), meeting)).to be_nil
  end

  it 'la campaña lo guarda (CampaignKit.sanitize)' do
    data = TrackingCampaigns::CampaignKit.sanitize('offer', { 'appointment_reminder' => { 'ai' => '0', 'text' => ' Hola ' } })
    expect(data['appointment_reminder']).to eq('ai' => false, 'text' => 'Hola', 'template' => '')
    expect(TrackingCampaigns::CampaignKit.sanitize('invite', {})['appointment_reminder']).to be_nil
  end
end
