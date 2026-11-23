# frozen_string_literal: true

require 'rails_helper'

# Campaña con Vendedor IA — probar la CAMPAÑA (no solo al vendedor): «Simular» la línea de tiempo para un contacto y
# «Prueba real» a los contactos de prueba con los toques cada pocos minutos.
RSpec.describe 'Motor2 campaign tests' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator, name: 'Ana Admin') }
  let(:api) { "/api/v1/accounts/#{account.id}/motor2_campaigns" }
  let(:headers) { admin.create_new_auth_token }
  let(:email_inbox) { create(:channel_email, account: account).inbox }
  let(:wa_inbox) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false).inbox }
  let!(:seller) do
    Motor2::Functions::Form.new(account, { kind: 'campaign_seller', name: 'Vendedor IA', enabled: true,
                                           settings: { 'purpose' => 'offer', 'relay' => 'person', 'user_id' => admin.id } }, user: admin).save
  end
  let(:mario) { create(:contact, account: account, name: 'Mario López', email: 'mario@ejemplo.com', phone_number: '+5218112345678') }

  def campaign(inbox: email_inbox, touches: {})
    account.tracking_campaigns.create!(
      name: 'Promo marzo', engine: '2', status: 'saved', tracking_template: seller, inbox: inbox, user: admin,
      scheduled_for: Time.current, email_subject: 'Hola {{contacto}}', brief: { 'kind' => 'offer', 'offer_what' => 'Mantenimiento' },
      touches: { 'attempts' => 3, 'every_value' => 2, 'every_unit' => 'days',
                 'emails' => [{ 'body' => 'Hola {{contacto}}, mira la promo' }, { 'body' => '' }] }.merge(touches)
    )
  end

  describe 'Simular' do
    it 'los toques personalizados, quién escribe cada uno y qué pasa según conteste' do
      rec = campaign
      post "#{api}/#{rec.id}/simulate", params: { contact_id: mario.id }, headers: headers, as: :json
      data = response.parsed_body
      expect(data['touches'].map { |t| t.slice('n', 'source') }).to eq([{ 'n' => 1, 'source' => 'campaign' }, { 'n' => 2, 'source' => 'ai' },
                                                                        { 'n' => 3, 'source' => 'ai' }])
      expect(data['touches'][0]).to include('subject' => 'Hola Mario', 'text' => 'Hola Mario, mira la promo')
      expect(data['touches'][2]['wait']).to eq('value' => 4, 'unit' => 'days')
      expect(data['outcomes'].first).to include('kind' => 'relay_person', 'to' => 'Ana Admin')
      expect(data['outcomes'].pluck('kind')).to include('discarded', 'handoff', 'no_reply')
    end

    it 'WhatsApp: avisa los toques sin plantilla (solo salen dentro de las 24 h)' do
      rec = campaign(inbox: wa_inbox, touches: { 'templates' => ['sample_shipping_confirmation'] })
      post "#{api}/#{rec.id}/simulate", params: { contact_id: mario.id }, headers: headers, as: :json
      data = response.parsed_body
      expect(data['touches'][0]).to include('source' => 'template', 'template' => 'sample_shipping_confirmation')
      expect(data['warnings']).to include('kind' => 'whatsapp_no_template', 'touches' => [2, 3])
    end
  end

  describe 'Prueba real' do
    it 'una copia oculta solo a los contactos de prueba, con toques en minutos; otra prueba termina la anterior' do # rubocop:disable RSpec/MultipleExpectations -- un recorrido
      rec = campaign
      post "#{api}/#{rec.id}/test_run", params: { recipients: [{ email: 'ana.prueba@ejemplo.com' }, { contact_id: mario.id }], every_minutes: 2 },
                                        headers: headers, as: :json
      expect(response).to have_http_status(:ok)
      run = rec.test_runs.last
      expect(run).to have_attributes(status: 'running', mode: 'batch', daily_cap: nil, respect_working_hours: false)
      expect(run.contact_trackings.pluck(:retry_interval_value, :retry_interval_unit).uniq).to eq([[2, 'minutes']])
      expect(response.parsed_body['contacts'].pluck('address')).to eq(['ana.prueba@ejemplo.com', 'mario@ejemplo.com'])
      expect(rec.reload.status).to eq('saved') # la campaña de verdad no se lanza

      get "/api/v1/accounts/#{account.id}/tracking_campaigns", headers: headers
      expect(response.parsed_body.pluck('id')).to eq([rec.id])

      post "#{api}/#{rec.id}/test_run", params: { recipients: [{ contact_id: mario.id }] }, headers: headers, as: :json
      expect(run.reload.status).to eq('finished')
      expect(run.contact_trackings.pluck(:status).uniq).to eq(['cancelled'])
      expect(rec.test_runs.last.entries.enrolled.count).to eq(1) # el seguimiento anterior ya no estorba

      delete "#{api}/#{rec.id}/test_run", headers: headers
      expect(rec.test_runs.last.status).to eq('finished')
    end

    it 'WhatsApp sin plantilla en el primer toque no arranca' do
      rec = campaign(inbox: wa_inbox)
      post "#{api}/#{rec.id}/test_run", params: { recipients: [{ phone: '+52 81 1234 5678' }] }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to include('plantilla')
    end
  end
end
