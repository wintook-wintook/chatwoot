# frozen_string_literal: true

require 'rails_helper'

# Campaña con Vendedor IA (Motor 2.0): la campaña trae su oferta y sus toques; el «Vendedor de campaña» la atiende.
RSpec.describe 'Motor2 campaigns API' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator, name: 'Ana Admin') }
  let(:api) { "/api/v1/accounts/#{account.id}/motor2_campaigns" }
  let(:headers) { admin.create_new_auth_token }
  let(:email_inbox) { create(:channel_email, account: account).inbox }
  let(:wa_inbox) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false).inbox }
  let!(:seller) do
    Motor2::Functions::Form.new(account, { kind: 'campaign_seller', name: 'Vendedor IA', enabled: true,
                                           settings: { 'purpose' => 'offer', 'offer_what' => 'Oferta del agente' } }, user: admin).save
  end
  let(:contacts) { Array.new(2) { |i| create(:contact, account: account, name: "Cliente #{i}", email: "c#{i}@ejemplo.com") } }

  # El dominio de la bandeja (SPF, DKIM, DMARC) sin ir al DNS de verdad.
  before do
    allow(TrackingCampaigns::EmailDomainCheck).to receive(:call)
      .and_return({ domain: 'example.com', free: false, spf: true, dmarc: true, dkim: true })
  end

  def body(extra = {})
    { name: 'Promo marzo', tracking_template_id: seller.id, inbox_id: email_inbox.id, email_subject: 'Hola {{contacto}}',
      brief: { kind: 'offer', offer_what: 'Mantenimiento gratis', offer_details: 'Hasta el 31' },
      touches: { attempts: 2, every_value: 3, every_unit: 'days',
                 emails: [{ body: 'Hola {{contacto}}, mira https://ejemplo.com/promo' }, { body: '' }] },
      audience: { source: { type: 'label', label: 'vip' },
                  filter_payload: [{ attribute_key: 'labels', filter_operator: 'equal_to', values: ['vip'], query_operator: nil }] } }
      .merge(extra)
  end

  def create_campaign(extra = {})
    post api, params: body(extra), headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    TrackingCampaign.find(response.parsed_body['id'])
  end

  it 'opciones: solo vendedores de campaña y bandejas de WhatsApp o correo, con sus plantillas aprobadas' do
    email_inbox
    wa_inbox
    create(:inbox, account: account, name: 'Chat web')
    get "#{api}/options", headers: headers
    data = response.parsed_body
    expect(data['sellers'].pluck('id')).to eq([seller.id])
    expect(data['inboxes'].pluck('channel_type')).to contain_exactly('Channel::Email', 'Channel::Whatsapp')
    wa = data['inboxes'].find { |i| i['channel_type'] == 'Channel::Whatsapp' }
    expect(wa['templates'].first).to include('name' => 'sample_shipping_confirmation', 'body' => a_string_including('{{1}}'))
  end

  it 'guarda la campaña 2.0 Guardada, con su oferta y toques, y el agente usa la oferta de la campaña' do
    campaign = create_campaign
    expect(campaign).to have_attributes(engine: '2', status: 'saved', inbox_id: email_inbox.id, tracking_template_id: seller.id)
    expect(campaign.brief).to include('kind' => 'offer', 'offer_what' => 'Mantenimiento gratis')
    expect(campaign.touches).to include('attempts' => 2, 'every_value' => 3)

    tracking = ContactTracking.new(tracking_template: seller, tracking_campaign: campaign)
    function = Motor2::Config.for(tracking).function
    expect(function.answer(:offer_what)).to eq('Mantenimiento gratis')
    expect(Motor2::Config.new(seller).function.answer(:offer_what)).to eq('Oferta del agente') # el agente no cambia
  end

  it 'no guarda sin vendedor o con un canal que no es WhatsApp ni correo' do
    post api, params: body(inbox_id: create(:inbox, account: account).id), headers: headers, as: :json
    expect(response.parsed_body['error']).to include('WhatsApp o de correo')
  end

  it 'la revisión no deja lanzar WhatsApp sin plantilla por toque' do
    campaign = create_campaign(inbox_id: wa_inbox.id, touches: { attempts: 2, templates: ['sample_shipping_confirmation', ''] })
    get "#{api}/#{campaign.id}/check", headers: headers
    items = response.parsed_body['items']
    expect(items.find { |i| i['key'] == 'touch_1' }['level']).to eq('ok')
    expect(items.find { |i| i['key'] == 'touch_2' }['level']).to eq('error')

    post "#{api}/#{campaign.id}/launch", headers: headers
    expect(response).to have_http_status(:unprocessable_entity)
    expect(campaign.reload.status).to eq('saved')
  end

  it 'al inscribir, cada seguimiento lleva los toques de la campaña y el correo escrito sale con sus datos y ligas contadas' do
    campaign = create_campaign
    campaign.update!(status: 'running', scheduled_for: 1.minute.ago)
    entry = TrackingCampaigns::Enroll.new(campaign, contacts.first, source: 'batch', agent: admin).call
    tracking = entry.contact_tracking
    expect(tracking).to have_attributes(max_attempts: 2, retry_interval_value: 3, retry_interval_unit: 'days', whatsapp_templates: [])

    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('FRONTEND_URL', '').and_return('https://app.kontrolya.test')
    text = Motor2::CampaignTouch.text(tracking)
    expect(text).to start_with('Hola Cliente,').and include('https://app.kontrolya.test/c/')
    token = text[%r{/c/(\S+)}, 1]

    get "/c/#{token}"
    expect(response).to redirect_to('https://ejemplo.com/promo')
    expect(campaign.clicks.count).to eq(1)

    tracking.update!(attempt_count: 1)
    expect(Motor2::CampaignTouch.text(tracking.reload)).to be_nil # el 2.º sin texto: lo escribe el agente
  end

  it 'no le vuelve a escribir si otra campaña 2.0 le escribió hace menos de los días de descanso' do
    first = create_campaign
    first.update!(status: 'running', scheduled_for: 1.minute.ago)
    TrackingCampaigns::Enroll.new(first, contacts.first, source: 'batch', agent: admin).call.contact_tracking.update!(status: 'completed')
    second = create_campaign(name: 'Otra', brief: body[:brief].merge(rest_days: 15))
    second.update!(status: 'running', scheduled_for: 1.minute.ago)
    entry = TrackingCampaigns::Enroll.new(second, contacts.first, source: 'batch', agent: admin).call
    expect(entry).to have_attributes(status: 'skipped', reason: 'recently_contacted')
  end

  it 'tablero y seguimiento: los que no les interesó van a otra campaña Guardada' do
    campaign = create_campaign
    campaign.update!(status: 'running', scheduled_for: 1.minute.ago)
    tracking = TrackingCampaigns::Enroll.new(campaign, contacts.first, source: 'batch', agent: admin).call.contact_tracking
    tracking.update!(attempt_count: 1)
    tracking.update_columns(outcome: 'discarded', motor2_state: { 'exit_reason' => 'Ya tiene proveedor' }) # rubocop:disable Rails/SkipsModelValidations

    get "#{api}/#{campaign.id}/results", headers: headers
    data = response.parsed_body
    expect(data['funnel']).to include('enrolled' => 1, 'sent' => 1)
    expect(data['exits']).to include('not_interested' => 1)
    expect(data['reasons']).to eq(['Ya tiene proveedor'])

    post "#{api}/#{campaign.id}/follow_up", params: { group: 'not_interested' }, headers: headers, as: :json
    copy = TrackingCampaign.find(response.parsed_body['id'])
    expect(copy).to have_attributes(engine: '2', status: 'saved')
    expect(copy.audience['contact_ids']).to eq([contacts.first.id])

    expect { post "#{api}/#{copy.id}/launch", headers: headers }.to have_enqueued_job(TrackingCampaigns::Motor2EnrollJob)
    expect(copy.reload.status).to eq('running')
  end

  describe 'lista fría de correos' do
    let(:csv) do
      Rack::Test::UploadedFile.new(StringIO.new(<<~CSV), 'text/csv', original_filename: 'lista.csv')
        Correo;Nombre;Empresa
        ana@ejemplo.com;Ana Ruiz;Grúas del Norte
        ANA@ejemplo.com;Ana repetida;
        info@ejemplo.com;Info;
        mal-correo;Nadie;
        baja@ejemplo.com;Se dio de baja;
        #{contacts.first.email};Ya es cliente;
      CSV
    end

    before do
      allow(ContactTrackings::EmailCheck).to receive(:domain_receives_mail?).and_return(true)
      EmailSuppression.add!(account, 'baja@ejemplo.com', 'opted_out')
    end

    def upload(campaign)
      post "#{api}/#{campaign.id}/list", params: { file: csv, name: 'Expo', cleanup_days: 15 }, headers: headers
      expect(response).to have_http_status(:ok)
      ProspectList.find(response.parsed_body.dig('list', 'id'))
    end

    it 'se limpia, reusa los contactos que ya existen y los nuevos quedan en cuarentena (no salen en Contactos)' do
      campaign = create_campaign
      list = upload(campaign)
      expect(list.stats).to include('rows' => 6, 'valid' => 2, 'created' => 1, 'existing' => 1)
      expect(list.stats['discarded']).to include('duplicate' => 1, 'role' => 1, 'invalid' => 1, 'suppressed' => 1)
      ana = account.contacts.from_email('ana@ejemplo.com')
      expect(ana).to have_attributes(list_quarantine: true, prospect_list_id: list.id)
      expect(contacts.first.reload.list_quarantine).to be(false)
      expect(campaign.reload.audience['contact_ids']).to contain_exactly(ana.id, contacts.first.id)

      get "/api/v1/accounts/#{account.id}/contacts", headers: headers
      expect(response.parsed_body['payload'].pluck('email')).not_to include('ana@ejemplo.com')
    end

    it 'solo para correo; con lista pide tope diario' do
      wa = create_campaign(inbox_id: wa_inbox.id, touches: { attempts: 1, templates: ['sample_shipping_confirmation'] })
      post "#{api}/#{wa.id}/list", params: { file: csv }, headers: headers
      expect(response.parsed_body['error']).to include('solo se puede usar en campañas por correo')

      campaign = create_campaign
      upload(campaign)
      get "#{api}/#{campaign.id}/check", headers: headers
      expect(response.parsed_body['items'].find { |i| i['key'] == 'daily_cap' }['level']).to eq('error')
    end

    it 'al contestar deja la cuarentena; los que nunca contestan se borran y las bajas van a la exclusión' do
      campaign = create_campaign
      list = upload(campaign)
      ana = account.contacts.from_email('ana@ejemplo.com')
      ProspectLists.promote!(ana)
      expect(ana.reload.list_quarantine).to be(false)

      ghost = account.contacts.create!(name: 'Fantasma', email: 'fantasma@ejemplo.com', prospect_list: list, list_quarantine: true,
                                       opted_out_at: Time.current)
      campaign.update!(ends_at: 20.days.ago, scheduled_for: 30.days.ago)
      ProspectLists::CleanupJob.perform_now
      expect(Contact.exists?(ghost.id)).to be(false)
      expect(Contact.exists?(ana.id)).to be(true)
      expect(EmailSuppression.exists?(account_id: account.id, email: 'fantasma@ejemplo.com')).to be(true)
      expect(list.reload).to have_attributes(cleaned_at: be_present)
    end
  end

  describe 'correo profesional: bandeja limpia, dominio y calentamiento' do
    def quarantined(campaign)
      account.contacts.create!(name: 'Fría', email: 'fria@ejemplo.com', list_quarantine: true,
                               additional_attributes: { 'company_name' => 'Grúas del Norte' }).tap do |c|
        campaign.update!(status: 'running', scheduled_for: 1.minute.ago)
        TrackingCampaigns::Enroll.new(campaign, c, source: 'batch', agent: admin).call
      end
    end

    it 'la conversación de un contacto en cuarentena nace pospuesta y sin asignar, y se calla después de cada toque' do
      campaign = create_campaign
      contact = quarantined(campaign)
      tracking = ContactTracking.find_by(contact_id: contact.id)
      conversation = TrackingCampaigns::TrackingBuilder.new(campaign, contact, agent: admin).open_conversation(tracking: tracking)
      expect(conversation).to have_attributes(status: 'snoozed', assignee_id: nil)

      tracking.update!(conversation_id: conversation.id)
      conversation.update!(status: :open, assignee: admin) # el 1.0 la reabre al mandar
      Motor2::ListConversation.quiet!(tracking)
      expect(conversation.reload).to have_attributes(status: 'snoozed', assignee_id: nil)

      ProspectLists.promote!(contact) # contestó: ya no se calla y queda ligado a su empresa
      expect(contact.reload.organization&.name).to eq('Grúas del Norte')
      conversation.update!(status: :open)
      Motor2::ListConversation.quiet!(tracking)
      expect(conversation.reload.status).to eq('open')
    end

    it 'revisión del dominio: con lista fría, sin SPF o con correo gratis no se lanza' do
      campaign = create_campaign
      campaign.update!(audience: { 'source' => { 'type' => 'list', 'list_id' => 1 }, 'contact_ids' => [1] }, daily_cap: 100)
      allow(TrackingCampaigns::EmailDomainCheck).to receive(:call).and_return({ domain: 'empresa.com', free: false, spf: false,
                                                                                dmarc: false, dkim: nil })
      items = TrackingCampaigns::Motor2Check.new(campaign.reload).call.index_by { |i| i[:key] }
      expect(items[:spf][:level]).to eq('error')
      expect(items[:dmarc][:level]).to eq('warning')
      expect(items[:warmup][:level]).to eq('warning')

      allow(TrackingCampaigns::EmailDomainCheck).to receive(:call).and_return({ domain: 'gmail.com', free: true })
      expect(TrackingCampaigns::Motor2Check.new(campaign).call.find { |i| i[:key] == :domain }[:level]).to eq('error')
    end

    it 'lee SPF, DMARC y DKIM del DNS' do
      allow(Rails.cache).to receive(:fetch).and_yield
      allow(TrackingCampaigns::EmailDomainCheck).to receive(:call).and_call_original
      allow(TrackingCampaigns::EmailDomainCheck).to receive(:texts) do |name|
        { 'empresa.com' => ['v=spf1 include:_spf.google.com ~all'], '_dmarc.empresa.com' => ['v=DMARC1; p=none'],
          'google._domainkey.empresa.com' => ['v=DKIM1; k=rsa; p=MIIB'] }.fetch(name, [])
      end
      expect(TrackingCampaigns::EmailDomainCheck.call('ventas@empresa.com')).to include(spf: true, dmarc: true, dkim: true)
      expect(TrackingCampaigns::EmailDomainCheck.call('yo@gmail.com')).to include(free: true)
    end

    it 'calentando el dominio el tope sube 50, 100, 200… y por lote cada contacto cae en su día' do
      expect((0..3).map { |d| TrackingCampaigns::Motor2Brief.warmup_cap(300, d) }).to eq([50, 100, 200, 300])
      expect([0, 49, 50, 149, 150, 349, 350].map { |i| TrackingCampaigns::Motor2Brief.warmup_day(i, 200) }).to eq([0, 0, 1, 1, 2, 2, 3])
    end

    it 'si rebota más del 5 % (desde 20 enviados) la campaña se pausa sola' do
      campaign = create_campaign
      campaign.update!(status: 'running', scheduled_for: 1.minute.ago)
      20.times do |i|
        c = account.contacts.create!(name: "C#{i}", email: "c#{i}@ejemplo.com")
        tracking = TrackingCampaigns::Enroll.new(campaign, c, source: 'batch', agent: admin).call.contact_tracking
        tracking.update_columns(attempt_count: 1, prospect_exit: i < 2 ? 'bounced' : nil) # rubocop:disable Rails/SkipsModelValidations
      end
      TrackingCampaigns::BounceGuard.check(campaign)
      expect(campaign.reload).to have_attributes(status: 'paused', paused_reason: a_string_including('10%'))
    end

    it 'en Contactos, «Prospectos de listas» muestra solo los que están en cuarentena' do
      account.contacts.create!(name: 'Fría', email: 'fria@ejemplo.com', list_quarantine: true)
      get "/api/v1/accounts/#{account.id}/contacts", params: { list_prospects: 'only' }, headers: headers
      expect(response.parsed_body['payload'].pluck('email')).to eq(['fria@ejemplo.com'])
    end
  end

  it '«Probar» con la oferta de la campaña sin guardarla' do
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' })
    allow_any_instance_of(Motor2::AnswerExtractor).to receive(:call).and_return({}) # rubocop:disable RSpec/AnyInstance
    prompts = []
    allow_any_instance_of(Motor2::Runner).to receive(:complete) do |_runner, messages| # rubocop:disable RSpec/AnyInstance
      prompts << messages.first[:content].to_s
      { 'role' => 'assistant', 'content' => '¡Claro! ¿Te interesa?' }
    end
    post "#{api}/test", params: { template_id: seller.id, brief: { kind: 'offer', offer_what: 'Pintura a mitad de precio' },
                                  messages: [{ role: 'user', content: '¿de qué se trata?' }] }, headers: headers, as: :json
    expect(response.parsed_body['reply']).to eq('¡Claro! ¿Te interesa?')
    expect(prompts.first).to include('Pintura a mitad de precio')
  end
end
