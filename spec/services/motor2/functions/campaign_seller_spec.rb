# frozen_string_literal: true

require 'rails_helper'

# Función «Vendedor de campaña» sobre el motor 2.0 (Plan-Motor-Agentes §11.16): toca la puerta y pasa el
# relevo. OpenAI no se llama: se simulan las respuestas del modelo (Motor2::Runner#complete).
RSpec.describe Motor2::Functions::CampaignSeller do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator, name: 'John') }
  let(:seller) { create(:user, account: account, role: :agent, name: 'Víctor Ventas') }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Mario Pérez') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, assignee: nil) }
  let(:settings) { { 'purpose' => 'offer', 'offer_what' => 'Capacitación', 'offer_details' => '20% hasta el 30 de noviembre' } }
  let!(:agent) { save_agent(settings) }

  def save_agent(answers, kind: 'campaign_seller', name: 'Campañas', extra: {})
    Motor2::Functions::Form.new(account, { kind: kind, name: name, enabled: true, inbox_ids: [inbox.id], settings: answers }.merge(extra),
                                user: admin).save
  end

  def tool_call(name, args)
    { 'role' => 'assistant', 'content' => nil,
      'tool_calls' => [{ 'id' => "call_#{name}", 'type' => 'function', 'function' => { 'name' => name, 'arguments' => args.to_json } }] }
  end

  def answer(text) = { 'role' => 'assistant', 'content' => text }

  def stub_model(*replies)
    allow_any_instance_of(Motor2::Runner).to receive(:complete).and_return(*replies) # rubocop:disable RSpec/AnyInstance
  end

  def incoming(text)
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming, content: text, sender: contact)
  end

  # La campaña ya le escribió: el seguimiento del agente vive en la conversación.
  def campaign_tracking(template = agent)
    ContactTracking.create!(Motor2::InboxRouter.attributes(template.reload, conversation))
  end

  def reply_to(message) = Motor2::ReplyJob.perform_now(message.id)

  def tools_for(template = agent)
    runner = Motor2::Runner.new(Motor2::Config.new(template.reload), state: Motor2::State.new, history: [])
    Motor2::Skills.for(runner).flat_map(&:tools).map { |t| t.dig(:function, :name) }
  end

  before do
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' })
    allow_any_instance_of(Motor2::AnswerCheck).to receive_messages(answers?: true, about_business?: true) # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(Motor2::AnswerExtractor).to receive(:call).and_return({}) # rubocop:disable RSpec/AnyInstance
    allow(TrackingCampaigns::ProspectClassifier).to receive(:call)
  end

  it 'no atiende bandejas: escribe por su canal con una plantilla por toque' do
    templated = save_agent(settings, name: 'Con plantillas',
                                     extra: { channel: { inbox_id: inbox.id, whatsapp_templates: %w[promo_1 promo_2], retry_value: 2,
                                                         retry_unit: 'days' } })
    expect(templated).to have_attributes(engine: '2', agent_function: 'campaign_seller', attending: false, attend_inbox_ids: [],
                                         inbox_id: inbox.id, whatsapp_templates: %w[promo_1 promo_2], retry_interval_value: 2,
                                         retry_interval_unit: 'days', follow_up_attempts: 2)
  end

  it 'el prompt trae la oferta; cada uso trae sus herramientas y no las de terminar' do
    runner = Motor2::Runner.new(Motor2::Config.new(agent.reload), state: Motor2::State.new, history: [])
    expect(Motor2::Prompt.new(runner, Motor2::Skills.for(runner)).system).to include('LA CAMPAÑA', 'OFRECER', 'Capacitación', '20% hasta',
                                                                                     'REGLAS DE LA CAMPAÑA')
    expect(tools_for).to include('le_interesa', 'no_esta_vez', 'no_contactar', 'mas_adelante', 'pasar_a_humano')
    expect(tools_for).not_to include('objetivo_cumplido', 'descartar', 'confirmar_asistencia')

    survey = save_agent({ 'purpose' => 'survey', 'survey_questions' => ['Del 0 al 10, ¿nos recomendarías?'] }, name: 'Encuesta')
    expect(tools_for(survey)).to include('guardar_respuesta')
    expect(tools_for(survey)).not_to include('le_interesa', 'buscar_en_fuentes')
  end

  it 'le interesa: pasa el relevo al agente de prospectos de la bandeja, sin contestar él; ese contesta el mismo mensaje' do
    prospects = save_agent({ 'objective' => 'handoff', 'question_list' => ['¿Qué buscas?'] }, kind: 'prospects', name: 'Prospectos')
    tracking = campaign_tracking
    stub_model(tool_call('le_interesa', { resumen: 'Quiere la capacitación' }), answer('[SIN_MENSAJE]'))
    message = incoming('sí me interesa, ¿cuánto cuesta?')

    expect { reply_to(message) }.to have_enqueued_job(Motor2::ReplyJob).with(message.id)
    expect(tracking.reload).to have_attributes(status: 'objective_met', outcome: 'relayed: Prospectos', prospect_stage: 'interested')
    following = ContactTracking.where(conversation_id: conversation.id, tracking_template_id: prospects.id).last
    expect(following).to have_attributes(status: 'active')
    expect(following.motor2_state).to include('welcome_sent' => true, 'from_campaign' => 'Quiere la capacitación')
    expect(conversation.messages.outgoing.where(private: false)).to be_empty
    expect(conversation.messages.where(private: true).last.content).to include('pasa a «Prospectos»')
  end

  it 'le interesa y no hay agente que siga: lo pasa a la persona elegida y avisa' do
    save_agent(settings.merge('relay' => 'person', 'user_id' => seller.id), name: 'Campañas persona').tap do |t|
      campaign_tracking(t)
    end
    stub_model(tool_call('le_interesa', { resumen: 'Quiere precio' }), answer('¡Con gusto! En un momento te contactan.'))
    reply_to(incoming('me interesa'))

    expect(conversation.reload.assignee_id).to eq(seller.id)
    expect(ContactTracking.find_by(conversation_id: conversation.id).status).to eq('paused')
    expect(conversation.messages.outgoing.where(private: false).last.content).to include('te contactan')
  end

  it '«no esta vez»: la respuesta fija pregunta por la próxima; «sí» deja la etiqueta y termina' do
    tracking = campaign_tracking
    stub_model(tool_call('no_esta_vez', { motivo: 'No tiene tiempo' }), answer('Entiendo, no hay problema 😊 ¿Te aviso de la próxima?'))
    reply_to(incoming('ahorita no tengo tiempo'))
    expect(tracking.reload).to have_attributes(status: 'active', outcome: 'not_now')
    expect(tracking.motor2_state['asked_future']).to be(true)

    stub_model(tool_call('futuras', { acepta: true }), answer('¡Va! Te aviso de la próxima. 😊'))
    reply_to(incoming('sí, avísame'))
    expect(tracking.reload).to have_attributes(status: 'cancelled', outcome: 'future_yes')
    expect(contact.reload.label_list).to include('avisar-promociones')
  end

  it '«no me manden nada»: baja de este tipo de campaña, con su etiqueta (gana la última voluntad)' do
    contact.update!(label_list: ['avisar-promociones'])
    tracking = campaign_tracking
    stub_model(tool_call('no_contactar', { motivo: 'No quiere' }), answer('Entendido, ya no te enviaremos promociones.'))
    reply_to(incoming('ya no quiero promociones'))
    expect(tracking.reload.status).to eq('cancelled')
    expect(contact.reload.label_list).to include('no-ofrecer')
    expect(contact.label_list).not_to include('avisar-promociones')
  end

  it '«ya no quiero nada de ustedes»: la IA lo marca como baja de todo (etiqueta «baja», ninguna campaña)' do
    tracking = campaign_tracking
    stub_model(tool_call('no_contactar', { motivo: 'No quiere nada', de_todo: true }), answer('Listo, ya no te escribiremos.'))
    reply_to(incoming('ya no quiero saber nada de ustedes'))
    expect(tracking.reload.status).to eq('cancelled')
    expect(contact.reload).to be_opted_out
    expect(contact.label_list).to include('baja')
    expect(contact.label_list).not_to include('no-ofrecer')
    expect(conversation.reload.label_list).to include('baja')
  end

  it '«No me manden nada»: baja de todo antes de la IA, con la etiqueta «baja» en el contacto y la conversación' do
    tracking = campaign_tracking
    stub_model(answer('No debería salir'))
    reply_to(incoming('No me manden nada, por favor'))
    expect(tracking.reload.status).to eq('cancelled')
    expect(contact.reload.label_list).to include('baja')
    expect(conversation.reload.label_list).to include('baja')
  end

  it 'invitar: confirma su lugar en el evento' do
    event = account.events.create!(name: 'Presentación', starts_at: 3.days.from_now)
    invite = save_agent({ 'purpose' => 'invite', 'event_id' => event.id }, name: 'Invitación')
    campaign_tracking(invite)
    stub_model(tool_call('confirmar_asistencia', { asistira: true }), answer('¡Te esperamos!'))
    reply_to(incoming('sí voy'))

    expect(event.attendees.find_by(contact: contact)).to have_attributes(status: 'confirmed', source: 'agent')
  end

  it 'encuesta: las preguntas en orden; con calificación baja levanta un caso' do
    account.case_types.create!(name: 'Soporte', case_class: :support)
    survey = save_agent({ 'purpose' => 'survey', 'survey_questions' => ['Del 0 al 10, ¿nos recomendarías?', '¿Qué mejoramos?'],
                          'user_id' => seller.id }, name: 'Encuesta')
    tracking = campaign_tracking(survey)
    stub_model(tool_call('guardar_respuesta', { respuesta: '5', calificacion: 5 }), answer('Gracias. ¿Qué mejoramos?'))
    reply_to(incoming('un 5'))
    stub_model(tool_call('guardar_respuesta', { respuesta: 'Contestar más rápido' }), answer('¡Gracias por tu tiempo!'))
    reply_to(incoming('que contesten más rápido'))

    expect(tracking.reload.motor2_state['survey'].keys).to eq(%w[1 2])
    expect(tracking.status).to eq('objective_met')
    expect(CaseTicket.find_by(contact: contact)).to have_attributes(priority: 'high', assignee_id: seller.id)
  end

  describe 'lo que comparten los tres agentes' do
    it 'deja etiquetas de cómo terminó (le interesa / no contactar)' do
      campaign_tracking
      stub_model(tool_call('no_contactar', { motivo: 'No lo necesita' }), answer('Entendido.'))
      reply_to(incoming('ya no quiero promociones'))
      expect(conversation.reload.label_list).to include('no-contactar')
    end

    it 'con seguimiento corto: si contesta y se queda a media plática, el agente lo retoma (no «3 días hábiles»)' do
      templated = save_agent(settings.merge('follow_up' => { 'nudges' => 2 }), name: 'Con seguimiento')
      tracking = campaign_tracking(templated)
      stub_model(answer('Es de 20 horas. ¿Te late que te pase los horarios?'))
      message = incoming('¿cuántas horas dura?')
      expect { reply_to(message) }.to have_enqueued_job(Motor2::FollowUpJob).with(tracking.id, message.id, 0)
      expect(tracking.reload).to have_attributes(status: 'active', max_attempts: tracking.max_attempts)
    end

    it 'cotizar y mandarla: se la manda, avisa y a los días le pregunta si la revisó' do
      account.case_types.create!(name: 'Ventas', case_class: :commercial)
      account.catalog_items.create!(name: 'Capacitación', price: 1500, kind: :service)
      quoting = save_agent(settings.merge('quote' => { 'mode' => 'send', 'follow_days' => 2 }, 'price_source' => 'catalog'),
                           name: 'Con cotización')
      tracking = campaign_tracking(quoting)
      stub_model(tool_call('cotizar', { partidas: [{ producto: 'capacitación', cantidad: 2 }] }), answer('Listo, te la mandé.'))
      expect { reply_to(incoming('mándame la cotización para 2')) }.to have_enqueued_job(Motor2::QuoteFollowUpJob)

      quote = account.quotes.last
      expect(quote).to have_attributes(status: 'sent')
      Motor2::QuoteFollowUpJob.perform_now(tracking.id, quote.id)
      expect(conversation.messages.outgoing.where(private: false).last.content).to include('¿Pudiste revisar la cotización', quote.folio)
    end

    it 'métricas: de los que contestaron, a cuántos les interesó' do
      campaign_tracking.update!(outcome: 'relayed: Prospectos')
      incoming('me interesa')
      metrics = Motor2::AgentMetrics.new(agent).call
      expect(metrics).to include(kind: 'campaign_seller', total: 1, rate: 100)
    end
  end

  describe 'imágenes y archivos' do
    def image(template, name, rule)
      create(:ai_agent_attachment, tracking_template: template, account: account, name: name,
                                   file: fixture_file_upload(Rails.root.join('spec/assets/sample.png'), 'image/png'))
      template.update!(resources: template.resources.to_h.merge('files' => template.file_rules.merge(name => rule)))
    end

    it 'el asistente guarda cuándo va cada archivo, con su descripción' do
      save_agent(settings, name: 'Con archivos', extra: { files: { 'foto' => { about: 'Foto del paquete', interest: true, attempts: [2] } } })
        .then { |t| expect(t.file_rules['foto']).to include('about' => 'Foto del paquete', 'interest' => true, 'ask' => false, 'attempts' => [2]) }
    end

    it 'al mostrar interés, la foto sale antes de que conteste el agente que sigue' do
      save_agent({ 'objective' => 'handoff', 'question_list' => ['¿Qué buscas?'] }, kind: 'prospects', name: 'Prospectos')
      image(agent, 'foto-paquete', { 'about' => 'Foto del paquete', 'interest' => true })
      campaign_tracking
      stub_model(tool_call('le_interesa', { resumen: 'Le interesa' }), answer('[SIN_MENSAJE]'))
      reply_to(incoming('me interesa'))

      sent = conversation.messages.outgoing.where(private: false).last
      expect(sent.attachments.count).to eq(1)
    end

    it 'al confirmar el evento manda el mapa con su mensaje' do
      event = account.events.create!(name: 'Expo', starts_at: 3.days.from_now)
      invite = save_agent({ 'purpose' => 'invite', 'event_id' => event.id }, name: 'Invitación')
      image(invite, 'mapa', { 'about' => 'Mapa para llegar', 'confirm' => true })
      campaign_tracking(invite)
      stub_model(tool_call('confirmar_asistencia', { asistira: true }), answer('¡Te esperamos! Te dejo el mapa.'))
      reply_to(incoming('sí voy'))

      expect(conversation.messages.outgoing.where(private: false).last.attachments.count).to eq(1)
    end

    it 'cotizar también es interés: la foto va con la cotización, una sola vez' do
      account.case_types.create!(name: 'Ventas', case_class: :commercial)
      account.catalog_items.create!(name: 'Capacitación', price: 1500, kind: :service)
      quoting = save_agent(settings.merge('quote' => { 'mode' => 'draft' }, 'price_source' => 'catalog'), name: 'Con cotización')
      image(quoting, 'foto-paquete', { 'about' => 'Foto del paquete', 'interest' => true })
      campaign_tracking(quoting)
      stub_model(tool_call('cotizar', { partidas: [{ producto: 'capacitación', cantidad: 2 }] }), answer('Listo, en un momento te la mandan.'),
                 tool_call('le_interesa', { resumen: 'Quiere la capacitación' }), answer('¡Con gusto! En un momento te contactan.'))
      reply_to(incoming('mándame la cotización para 2'))
      expect(conversation.messages.outgoing.where(private: false).last.attachments.count).to eq(1)

      reply_to(incoming('sí, la quiero'))
      expect(conversation.messages.outgoing.where(private: false).sum { |m| m.attachments.count }).to eq(1)
    end

    it 'Invitar: con la palabra clave van los archivos de «al confirmar» aunque la IA no use ya_lo_hizo' do
      event = account.events.create!(name: 'Expo', starts_at: 3.days.from_now)
      invite = save_agent({ 'purpose' => 'invite', 'event_id' => event.id, 'offer_goal' => 'external', 'goal_keyword' => 'REGISTRADO' },
                          name: 'Registro')
      image(invite, 'mapa', { 'about' => 'Mapa para llegar', 'confirm' => true })
      campaign_tracking(invite)
      stub_model(answer('¡Listo, ya quedaste registrado!'))
      reply_to(incoming('REGISTRADO'))
      expect(conversation.messages.outgoing.where(private: false).last.attachments.count).to eq(1)
    end

    it 'no dice que manda la foto si no la manda' do
      campaign_tracking
      stub_model(answer('Claro, te mando la foto del paquete.'), answer('Claro, el paquete incluye 10 horas.'))
      reply_to(incoming('¿tienes fotos?'))
      expect(conversation.messages.outgoing.where(private: false).last.content).to eq('Claro, el paquete incluye 10 horas.')
    end
  end
end
