# frozen_string_literal: true

require 'rails_helper'

# Campaña con Vendedor IA — las reglas de cada toque y de la respuesta (revisión 2026-11-23): horario y topes en
# TODOS los toques, un mensaje de campañas al día por contacto, baja y persona que interviene; contestar detiene los
# toques; la clasificación no cierra (decide el vendedor); un seguimiento viejo de la bandeja no bloquea la campaña.
RSpec.describe 'Motor2 campaign send rules' do # rubocop:disable RSpec/DescribeClass -- reglas de varias piezas
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:channel_email, account: account).inbox }
  let(:seller) do
    Motor2::Functions::Form.new(account, { kind: 'campaign_seller', name: 'Vendedor', enabled: true,
                                           settings: { 'relay' => 'person', 'user_id' => admin.id } }, user: admin).save
  end
  let(:contact) { create(:contact, account: account, name: 'Mario', email: 'mario@ejemplo.com') }
  let(:zone) { 'America/Mexico_City' }

  def campaign(attrs = {})
    account.tracking_campaigns.create!({ name: 'Promo', engine: '2', status: 'running', tracking_template: seller, inbox: inbox, user: admin,
                                         scheduled_for: 1.day.ago, touches: { 'attempts' => 3, 'every_value' => 1, 'every_unit' => 'days' },
                                         brief: { 'kind' => 'offer', 'offer_what' => 'Mantenimiento' } }.merge(attrs))
  end

  def tracking(camp, attrs = {})
    ContactTracking.create!({ account: account, contact: contact, inbox: inbox, tracking_template: seller, tracking_campaign: camp,
                              scheduled_for: 1.minute.from_now, status: 'scheduled', max_attempts: 3, attempt_count: 1, objective: 'Vender la promo',
                              retry_interval_value: 1, retry_interval_unit: 'days' }.merge(attrs))
  end

  def gate(trk, now) = TrackingCampaigns::SendGate.new(trk.reload, now: now).call

  before { inbox.update!(timezone: zone) }

  describe 'SendGate' do
    let(:friday_night) { Time.find_zone(zone).local(2026, 11, 27, 22, 0) }

    it 'de noche o en fin de semana espera al siguiente día hábil a las 9 (sin horario en la bandeja)' do
      decision = gate(tracking(campaign), friday_night)
      expect(decision).to include(action: :wait, reason: 'hours')
      expect(decision[:at]).to eq(Time.find_zone(zone).local(2026, 11, 30, 9, 0))
    end

    it 'un mensaje de campañas al día por contacto' do
      other = campaign(name: 'Otra')
      tracking(other, status: 'completed', last_attempt_at: Time.find_zone(zone).local(2026, 11, 26, 10, 0))
      decision = gate(tracking(campaign), Time.find_zone(zone).local(2026, 11, 26, 15, 0))
      expect(decision).to include(action: :wait, reason: 'frequency')
      expect(decision[:at]).to eq(Time.find_zone(zone).local(2026, 11, 27, 10, 0))
    end

    it 'el tope del día cuenta todos los toques' do
      camp = campaign(daily_cap: 1)
      now = Time.find_zone(zone).local(2026, 11, 26, 11, 0)
      other = create(:contact, account: account, email: 'otro@ejemplo.com')
      ContactTracking.create!(account: account, contact: other, inbox: inbox, tracking_template: seller, tracking_campaign: camp,
                              scheduled_for: 1.minute.from_now, status: 'scheduled', max_attempts: 3, attempt_count: 2,
                              last_attempt_at: now - 1.hour, retry_interval_value: 1, retry_interval_unit: 'days', objective: 'Vender la promo')
      expect(gate(tracking(camp), now)).to include(action: :wait, reason: 'daily_cap')
    end

    it 'baja, fin de la campaña y persona que ya lo atiende' do
      camp = campaign
      trk = tracking(camp)
      now = Time.find_zone(zone).local(2026, 11, 26, 11, 0)
      expect(gate(trk, now)).to be_nil

      camp.update!(ends_at: now - 1.hour)
      expect(gate(trk, now)).to include(action: :cancel, reason: 'campaign_ended')
      camp.update!(ends_at: nil)

      contact.update!(opted_out_at: Time.current)
      expect(gate(trk, now)).to include(action: :cancel, reason: 'opted_out')
    end

    it 'en «Prueba real» no espera horario ni topes' do
      test_copy = campaign(test_of: campaign(name: 'Real'))
      expect(gate(tracking(test_copy), friday_night)).to be_nil
    end

    it 'hold! reprograma sin contar el intento' do
      trk = tracking(campaign)
      at = 1.day.from_now
      TrackingCampaigns::SendGate.hold!(trk, { action: :wait, at: at, reason: 'hours' }, previous_attempt_at: nil)
      expect(trk.reload).to have_attributes(status: 'scheduled', attempt_count: 1, last_attempt_at: nil)
      expect(trk.scheduled_for).to be_within(1.second).of(at)
      expect(trk.motor2_state['send_wait']).to eq('hours')
    end
  end

  describe 'al contestar' do
    it 'la clasificación anota la etapa pero no cierra el seguimiento de una campaña 2.0' do
      trk = tracking(campaign)
      message = Message.new(account: account, content: 'no gracias')
      classifier = TrackingCampaigns::ProspectClassifier.new(trk, message)
      classifier.send(:apply, 'not_interested')
      expect(trk.reload).to have_attributes(status: 'scheduled', prospect_exit: nil, prospect_stage: 'replied')
    end
  end

  describe 'inscribir' do
    it 'un seguimiento «solo contesta» viejo de la bandeja ya no deja fuera al contacto' do
      old = ContactTracking.create!(account: account, contact: contact, inbox: inbox, tracking_template: seller, status: 'active',
                                    scheduled_for: 10.years.from_now, max_attempts: 1, attempt_count: 0, objective: 'Atender la bandeja')
      old.update_columns(updated_at: 10.days.ago) # rubocop:disable Rails/SkipsModelValidations
      entry = TrackingCampaigns::Enroll.new(campaign(scheduled_for: Time.current), contact, source: 'batch', agent: admin).call
      expect(entry.status).to eq('enrolled')
      expect(old.reload.status).to eq('completed')
    end
  end

  describe 'la revisión antes de lanzar' do
    it 'sin OpenAI, cita sin calendarios y relevo sin nadie son rojos' do
      camp = campaign(status: 'saved', brief: { 'kind' => 'offer', 'offer_what' => 'X', 'offer_goal' => 'appointment', 'relay' => 'person' })
      errors = TrackingCampaigns::Motor2Check.new(camp).call.select { |i| i[:level] == 'error' }.pluck(:key)
      expect(errors).to include(:ai, :appointment, :relay)
    end
  end

  describe 'resultados' do
    it 'no contestó solo cuando ya no le quedan toques; por toque' do
      camp = campaign
      tracking(camp, status: 'scheduled', last_attempt_at: 1.hour.ago, motor2_state: { 'touches_sent' => 1 })
      other = create(:contact, account: account, email: 'b@ejemplo.com')
      ContactTracking.create!(account: account, contact: other, inbox: inbox, tracking_template: seller, tracking_campaign: camp,
                              scheduled_for: 1.minute.from_now, status: 'completed', max_attempts: 3, attempt_count: 3,
                              last_attempt_at: 1.hour.ago, motor2_state: { 'touches_sent' => 3 }, objective: 'Vender la promo')
      data = TrackingCampaigns::Motor2Results.new(camp).call
      expect(data[:exits]).to include(no_reply: 1, in_progress: 1)
      expect(data[:touches].pluck(:sent)).to eq([2, 1, 1])
    end
  end
end
