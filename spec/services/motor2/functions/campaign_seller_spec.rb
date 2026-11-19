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
    expect(Motor2::Prompt.new(runner, Motor2::Skills.for(runner)).system).to include('LA OFERTA', 'OFRECER', 'Capacitación', '20% hasta')
    expect(tools_for).to include('le_interesa', 'no_le_interesa', 'pasar_a_humano')
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

  it 'no le interesa: se despide y no hay más toques' do
    tracking = campaign_tracking
    stub_model(tool_call('no_le_interesa', { motivo: 'No lo necesita' }), answer('Gracias, ¡buen día!'))
    reply_to(incoming('no gracias'))
    expect(tracking.reload.status).to eq('cancelled')
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
end
