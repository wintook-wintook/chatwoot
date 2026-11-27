# frozen_string_literal: true

require 'rails_helper'

# Campaña con IA — la ficha, las ligas, el objetivo, las respuestas fijas y las etiquetas del contacto
# (TrackingCampaigns::CampaignKit), lo que sabe la IA (Motor2::Functions::CampaignSeller), quién ya no entra
# (Enroll), los datos de cada contacto (ContactFacts), la encuesta por correo (SurveyLink) y los «Casos».
RSpec.describe TrackingCampaigns::CampaignKit do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:channel_email, account: account).inbox }
  let(:seller) { Motor2::Functions::Form.new(account, { kind: 'campaign_seller', name: 'Vendedor', enabled: true, settings: {} }, user: admin).save }
  let(:contact) { create(:contact, account: account, name: 'Mario López', email: 'mario@ejemplo.com') }
  let(:invite) do
    { 'kind' => 'invite', 'offer_goal' => 'external', 'goal_keyword' => ' REGISTRADO ', 'offer_what' => 'Lanzamiento',
      'facts' => { 'when' => 'Viernes 13, 9:15', 'not_for' => 'Clientes finales', 'price' => 'no es de invitar' },
      'links' => [{ 'name' => 'Registro', 'url' => 'https://zoom.us/r', 'use' => 'package' },
                  { 'name' => 'Directo', 'url' => 'https://zoom.us/j', 'use' => 'problem' }, { 'name' => 'Mala', 'url' => 'javascript:alert(1)' }],
      'labels' => { 'achieved' => 'Ya Registrado!', 'future_yes' => 'volver-a-invitar', 'opt_out' => 'no-invitar' },
      'content' => 'Regístrate: https://zoom.us/r' }
  end

  def brief(raw) = TrackingCampaigns::Motor2Brief.brief(raw)

  def campaign(raw, attrs = {})
    account.tracking_campaigns.create!({ name: 'Campaña', engine: '2', status: 'running', tracking_template: seller, inbox: inbox, user: admin,
                                         scheduled_for: 1.day.ago, brief: brief(raw), touches: { 'attempts' => 1 } }.merge(attrs))
  end

  def function_for(camp) = Motor2::Config.new(seller.reload, answers: TrackingCampaigns::Motor2Brief.seller_answers(camp)).function

  it 'guarda los campos de la ficha de su tipo, las ligas válidas con su uso y etiquetas como las de la cuenta' do
    data = brief(invite)
    expect(data).to include('offer_goal' => 'external', 'goal_keyword' => 'REGISTRADO')
    expect(data['facts']).to eq('when' => 'Viernes 13, 9:15', 'not_for' => 'Clientes finales') # «price» no es de Invitar
    expect(data['links'].pluck('name', 'use')).to eq([%w[Registro package], %w[Directo problem]])
    expect(data['labels']).to eq('achieved' => 'ya-registrado', 'future_yes' => 'volver-a-invitar', 'opt_out' => 'no-invitar')
    expect(brief(invite.merge('offer_goal' => 'appointment'))['offer_goal']).to eq('confirm') # no es de Invitar: el primero
  end

  it 'sin etiquetas guardadas usa las de fábrica; vacía es «sin etiqueta»; la respuesta vacía es la de fábrica' do
    expect(described_class.label({ 'kind' => 'offer', 'offer_goal' => 'external' }, 'achieved')).to eq('compro')
    expect(described_class.label({ 'kind' => 'offer', 'labels' => { 'opt_out' => '' } }, 'opt_out')).to eq('')
    expect(described_class.reply({ 'kind' => 'invite' }, 'not_now')).to include('próximo evento')
    expect(described_class.reply({ 'kind' => 'invite', 'replies' => { 'not_now' => 'Va' } }, 'not_now')).to eq('Va')
    expect(described_class.options['renew'][:asks_future]).to be(false)
  end

  it 'la IA recibe el objetivo, la ficha, las ligas con su uso y las preguntas autorizadas' do
    camp = campaign(invite.merge('objections' => [{ 'objection' => '¿Puedo ir solo a la demo?', 'answer' => 'Sí' }]))
    prompt = function_for(camp).prompt
    expect(prompt).to include('«REGISTRADO»', 'LA FICHA', 'Cuándo: Viernes 13', 'no se lo preguntes', 'https://zoom.us/j — SOLO si tiene un problema',
                              'PREGUNTAS Y OBJECIONES AUTORIZADAS', '¿Puedo ir solo a la demo?')
  end

  it 'la revisión pide la palabra clave; no avisa de la liga fuera del texto (se agrega sola)' do
    wa = create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false).inbox
    camp = campaign(invite.merge('goal_keyword' => '', 'content' => 'Sin liga'), inbox: wa)
    items = TrackingCampaigns::Motor2Check.new(camp).call.index_by { |i| i[:key] }
    expect(items[:keyword][:level]).to eq('error')
    expect(items).not_to have_key(:link_Registro)
    expect(items[:facts][:level]).to eq('ok')
  end

  it 'el que tiene la etiqueta «no…» del tipo ya no entra a la siguiente campaña de ese tipo (sí a otras)' do
    contact.update!(label_list: ['no-invitar'])
    result = TrackingCampaigns::Enroll.new(campaign(invite), contact, source: 'batch').call
    expect(account.tracking_campaigns.last.entries.find_by(contact: contact)).to have_attributes(status: 'skipped', reason: 'excluded_label')
    expect(result).to be_present
    other = campaign({ 'kind' => 'offer', 'offer_what' => 'Promo' }, name: 'Otra')
    TrackingCampaigns::Enroll.new(other, contact, source: 'batch').call
    expect(other.entries.find_by(contact: contact)&.reason).not_to eq('excluded_label')
  end

  it 'con la campaña, «no me inviten» lo decide su agente; «darme de baja» sí es la baja general' do
    expect(ContactTrackings::OptOut.hard_requested_in?('no me inviten más')).to be(false)
    expect(ContactTrackings::OptOut.hard_requested_in?('quiero darme de baja')).to be(true)
    expect(ContactTrackings::OptOut.hard_requested_in?('STOP')).to be(true)
  end

  describe 'las etiquetas del contacto' do
    it 'gana la última voluntad: «no-invitar» quita «volver-a-invitar» y se crea la etiqueta en la cuenta' do
      contact.update!(label_list: %w[volver-a-invitar vip])
      TrackingCampaigns::ContactLabels.apply(contact, add: 'no-invitar', remove: ['volver-a-invitar'], kind: 'opt_out')
      expect(contact.reload.label_list).to contain_exactly('no-invitar', 'vip')
      expect(account.labels.find_by(title: 'no-invitar')).to be_present
    end
  end

  describe 'datos de cada contacto (Reactivar y Recordar)' do
    it 'lo que le vence sale de su contrato activo; si no tiene, de su saldo en Cobranza' do
      type = account.contract_types.create!(name: 'Pólizas')
      account.contracts.create!(contact: contact, contract_type: type, title: 'Póliza anual', price: 1800, starts_on: 1.year.ago.to_date,
                                next_charge_on: Date.new(2026, 12, 15))
      values = TrackingCampaigns::ContactFacts.new(contact).values
      expect(values).to include('due_what' => 'Póliza anual', 'due_amount' => '$1,800.00 MXN', 'last_purchase' => 'Póliza anual')
      expect(values['due_date']).to include('diciembre')
      expect(Motor2::CampaignTouch.fill('Te vence {{vence}} por {{monto}}', contact)).to include('diciembre', '$1,800.00 MXN')
    end
  end

  describe 'Encuesta por correo' do
    let(:survey) { campaign({ 'kind' => 'survey', 'survey_questions' => ['Del 0 al 10, ¿nos recomiendas?', '¿Qué mejoramos?'] }) }
    let(:tracking) do
      ContactTracking.create!(account: account, contact: contact, inbox: inbox, tracking_template: seller, tracking_campaign: survey,
                              scheduled_for: 1.minute.from_now, status: 'active', max_attempts: 1, attempt_count: 1, objective: 'Encuesta')
    end

    before { allow(TrackingCampaigns::SurveyLink).to receive(:host).and_return('https://app.ejemplo.com') }

    it 'el correo lleva la primera pregunta con botones del 0 al 10' do
      text = TrackingCampaigns::SurveyLink.append(survey, tracking, 'Hola Mario')
      expect(text).to include('**Del 0 al 10, ¿nos recomiendas?**', '[0](https://app.ejemplo.com/encuesta/', '[10](')
      expect(TrackingCampaigns::SurveyLink.read(text[%r{/encuesta/([^)]+)\)}, 1])).to eq([tracking.id, 0])
    end
  end

  describe 'Casos' do
    it 'se arman con lo que tiene la campaña' do
      camp = campaign(invite)
      keys = TrackingCampaigns::Motor2Cases.new(seller.reload, TrackingCampaigns::Motor2Brief.seller_answers(camp)).list.pluck(:key)
      expect(keys).to include('interest', 'keyword', 'not_done', 'not_now', 'future_yes', 'opt_out', 'thanks', 'problem_link', 'resend_link')
      expect(keys).not_to include('confirm', 'later')

      survey = campaign({ 'kind' => 'survey', 'survey_questions' => ['¿Qué tal?'] }, name: 'Encuesta')
      expect(TrackingCampaigns::Motor2Cases.new(seller.reload, TrackingCampaigns::Motor2Brief.seller_answers(survey)).list.pluck(:key))
        .to eq(%w[survey_yes survey_answer opt_out])
    end

    it 'revisa lo que hizo la IA con sus herramientas y que traiga la liga exacta' do
      cases = TrackingCampaigns::Motor2Cases.new(seller.reload, TrackingCampaigns::Motor2Brief.seller_answers(campaign(invite)))
      result = { reply: 'Aquí tienes la liga: https://zoom.us/j', trace: { 'tools' => [{ 'name' => 'mandar_liga', 'ok' => true }] } }
      allow(Motor2::Probe).to receive(:new).and_return(instance_double(Motor2::Probe, call: result))
      expect(cases.run('problem_link')).to include(ok: true, tools: ['mandar_liga'])
      expect(cases.run('keyword')).to include(ok: false)
    end
  end
end
