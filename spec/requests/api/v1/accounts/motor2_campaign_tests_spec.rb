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
      expect(data['outcomes'].pluck('kind')).to include('not_now', 'opt_out', 'handoff', 'no_reply')
    end

    it 'WhatsApp: avisa los toques sin plantilla (solo salen dentro de las 24 h)' do
      rec = campaign(inbox: wa_inbox, touches: { 'templates' => ['sample_shipping_confirmation'] })
      post "#{api}/#{rec.id}/simulate", params: { contact_id: mario.id }, headers: headers, as: :json
      data = response.parsed_body
      expect(data['touches'][0]).to include('source' => 'template', 'template' => 'sample_shipping_confirmation')
      expect(data['warnings']).to include('kind' => 'whatsapp_no_template', 'touches' => [2, 3])
    end
  end

  describe 'Lo de la campaña encima del vendedor' do
    let(:beto) { create(:user, account: account, name: 'Beto Ventas') }

    it 'el relevo de la campaña gana; sin elegir, el del vendedor' do
      rec = campaign
      rec.update!(brief: rec.brief.merge('relay' => 'person', 'relay_user_id' => beto.id))
      post "#{api}/#{rec.id}/simulate", params: { contact_id: mario.id }, headers: headers, as: :json
      expect(response.parsed_body['outcomes'].first).to include('kind' => 'relay_person', 'to' => 'Beto Ventas')
      expect(TrackingCampaigns::Motor2Check.new(rec).call.find { |i| i[:key] == :relay }[:text]).to include('de la campaña')

      rec.update!(brief: rec.brief.except('relay', 'relay_user_id'))
      post "#{api}/#{rec.id}/simulate", params: { contact_id: mario.id }, headers: headers, as: :json
      expect(response.parsed_body['outcomes'].first['to']).to eq('Ana Admin')
    end

    it 'objeciones: las de la oferta y las generales del vendedor que la campaña no repite' do
      seller.update!(motor2: seller.motor2.deep_merge('answers' => { 'objections' => [
                                                        { 'objection' => 'Está caro', 'answer' => 'general' },
                                                        { 'objection' => 'Ya tengo proveedor', 'answer' => 'comparemos' }
                                                      ] }))
      brief = TrackingCampaigns::Motor2Brief.brief('objections' => [{ 'objection' => 'está caro', 'answer' => 'incluye instalación' }])
      rec = campaign.tap { |c| c.update!(brief: c.brief.merge(brief.slice('objections'))) }
      prompt = Motor2::Config.for(ContactTracking.new(tracking_template: seller, tracking_campaign: rec)).function.prompt
      expect(prompt).to include('incluye instalación', 'comparemos')
      expect(prompt).not_to include('→ general')
    end
  end

  describe 'Imágenes y archivos de esta oferta' do
    let(:png) { Rack::Test::UploadedFile.new(Rails.root.join('spec/assets/sample.png'), 'image/png') }

    def upload(rec, extra = {})
      post "#{api}/#{rec.id}/files", params: { file: png }.merge(extra), headers: headers
      expect(response).to have_http_status(:created)
      rec.files.find(response.parsed_body['id'])
    end

    it 'se suben a la campaña con su regla y van en su toque, antes que los del vendedor' do # rubocop:disable RSpec/MultipleExpectations -- un recorrido
      rec = campaign
      file = upload(rec, about: 'Foto de la promo')
      expect(file).to have_attributes(name: 'sample', tracking_template_id: nil)
      patch "#{api}/#{rec.id}/files/#{file.id}", params: { rules: { about: 'Foto de la promo', attempts: [2], interest: true } },
                                                 headers: headers, as: :json
      expect(file.reload.rules).to include('attempts' => [2], 'interest' => true, 'ask' => false)
      expect(upload(rec).name).to eq('sample-2') # sin repetir nombre

      tracking = ContactTracking.new(tracking_template: seller, tracking_campaign: rec)
      expect(ContactTrackings::AttemptFiles.names_for(tracking, 2)).to eq(['sample'])
      expect(ContactTrackings::AttemptFiles.names_for(tracking, 1)).to eq([])
      config = Motor2::Config.for(tracking)
      expect(Motor2::Skills::Files.with_rule(config, 'interest', config.attachments)).to eq(['sample'])

      post "#{api}/#{rec.id}/simulate", params: { contact_id: mario.id }, headers: headers, as: :json
      expect(response.parsed_body['touches'][1]['files']).to eq(['sample'])
      expect(response.parsed_body['outcomes'].first['files']).to eq(['sample'])
    end

    it 'la «Prueba real» usa los de su campaña y «Duplicar» se los lleva' do
      rec = campaign
      file = upload(rec)
      file.update!(rules: { 'attempts' => [1] })
      copy = account.tracking_campaigns.create!(rec.slice(:tracking_template_id, :inbox_id, :engine, :touches, :brief)
                                                   .merge(name: 'Prueba', status: 'running', test_of: rec, user: admin))
      expect(ContactTrackings::AttemptFiles.names_for(ContactTracking.new(tracking_template: seller, tracking_campaign: copy), 1))
        .to eq(['sample'])

      post "#{api}/#{rec.id}/duplicate", headers: headers, as: :json
      dup = TrackingCampaign.find(response.parsed_body['id'])
      expect(dup.files.map { |f| [f.name, f.rules['attempts']] }).to eq([['sample', [1]]])
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
