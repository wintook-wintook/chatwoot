# frozen_string_literal: true

# Probador de agentes — el canal de pruebas: bandejas API SIN webhook (un mensaje ahí no sale a
# ninguna parte) que son SOLO del probador: llevan la marca `agent_tester` en el canal y se crean
# solas («Probador de agentes · gpt-4o»). Nunca se toma otra bandeja de la cuenta: antes se usaba
# la primera API sin webhook (TestBattery.sandbox_inbox) y en dev cayó en bandejas reales del
# cliente («AGENTE ESCUELA Test API», cuenta 1128), con sus pláticas y su hook del bot cambiado.
#
# Una bandeja por modelo: el 1.0 elige el modelo por bandeja (ContactTrackings::EngineConfig, y lo
# leen también KnowledgeBaseResponseService y AskedConsulta), así que con una sola bandeja dos
# pruebas simultáneas de agentes con modelos distintos se pisaban el modelo. Cada bandeja fija el
# suyo al crearse y no cambia.
#
# Cada plática de prueba es un contacto y una conversación nuevos, con el agente asignado como lo
# asignan las automatizaciones (ActionService#assign_tracking_template). El cliente escribe y
# contesta el motor de verdad (1.0 o 2.0). El seguimiento queda «activo» para que no salgan
# intentos a media prueba; `finish` lo cierra al terminar y AgentTester::CleanupJob borra lo viejo.
class AgentTester::Sandbox
  INBOX_NAME = 'Probador de agentes'
  MARK = 'agent_tester'

  def initialize(account)
    @account = account
  end

  # La bandeja del probador para ese modelo (se crea si no existe).
  def inbox(model = ContactTrackings::EngineConfig::DEFAULT_MODEL)
    @inboxes ||= {}
    @inboxes[model] ||= find_inbox(model) || create_inbox(model)
  end

  # Las pláticas del probador, estén en la bandeja que estén (las de antes quedaron en bandejas reales).
  def conversations = @account.conversations.where("conversations.additional_attributes ->> '#{MARK}' = 'true'")

  # → la conversación de prueba (nil si no se pudo asignar el agente).
  # seleccion: 'on' | 'off' fuerza la búsqueda de predefinidas solo en esta plática
  #            (KnowledgeBase::Selection); nil = la de la cuenta.
  # variables: las de la plática donde se guardó la prueba (CARRERA, PRODUCTO…), puestas antes
  #            de que el cliente escriba.
  def start(template, user:, seleccion: nil, variables: nil)
    box = inbox(ContactTrackings::EngineConfig.model_for(template.inbox))
    contact = @account.contacts.create!(name: "Probador · #{user&.name || 'prueba'} · #{template.name}".first(100),
                                        additional_attributes: { MARK => true })
    contact_inbox = ContactInbox.create!(contact: contact, inbox: box, source_id: SecureRandom.uuid)
    conversation = Conversation.create!(account: @account, inbox: box, contact: contact, contact_inbox: contact_inbox,
                                        status: :open, additional_attributes: test_attributes(user, seleccion))
    ActionService.new(conversation).assign_tracking_template([template.id], inbox_id: box.id)
    tracking = tracking_for(conversation)
    return nil unless tracking

    tracking.update_columns(status: 'active', updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    seed_variables(tracking, conversation, variables)
    conversation
  end

  # Las variables de una plática (solo las que tienen valor distinto al inicial), para guardarlas
  # con la prueba.
  def variables_for(conversation)
    tracking = tracking_for(conversation)
    return {} if tracking.nil? || Motor2.on?(tracking.tracking_template)

    definition = ContactTrackings::ConversationVariables.definition_for(tracking)
    return {} if definition.blank?

    ContactTrackings::ConversationVariables.current(tracking, conversation, definition)
                                           .reject { |nombre, valor| valor.blank? || definition.initial[nombre] == valor }
  rescue StandardError
    {}
  end

  def say(conversation, text)
    conversation.messages.create!(account: @account, inbox: conversation.inbox, sender: conversation.contact,
                                  message_type: :incoming, content: text.to_s.strip.first(2000))
  end

  def tracking_for(conversation) = ContactTracking.where(conversation_id: conversation.id).order(:id).last

  # Al terminar una prueba: el seguimiento se cierra y la plática se resuelve, para que no quede
  # abierta en la cuenta. Sigue legible (la bitácora la abre con «Seguir la plática»). Sin callbacks:
  # resolverla «de verdad» dispararía las automatizaciones, webhooks y reportes de la cuenta.
  def finish(conversation)
    return unless conversation

    tracking_for(conversation)&.update_columns(status: 'completed', updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    conversation.update_columns(status: Conversation.statuses[:resolved], updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  rescue StandardError => e
    Rails.logger.warn("[AgentTester] cerrar la plática #{conversation&.id}: #{e.message}")
  end

  # Lo que pasó después de `after_id`: respuestas del agente (con su traza) y notas internas.
  def since(conversation, after_id)
    conversation.messages.where('id > ?', after_id.to_i).where(message_type: :outgoing).order(:id).map do |m|
      attrs = m.content_attributes.to_h
      { id: m.id, content: m.content.to_s, private: m.private, created_at: m.created_at,
        files: m.attachments.map { |a| a.file&.filename.to_s }.compact_blank,
        trace: AgentTester::Trace.normalize(attrs) }
    end
  end

  private

  def test_attributes(user, seleccion)
    attrs = { MARK => true, 'agent_tester_user_id' => user&.id }
    attrs[KnowledgeBase::Selection::FORCE_KEY] = seleccion if %w[on off].include?(seleccion)
    attrs
  end

  def seed_variables(tracking, conversation, variables)
    return if variables.blank? || Motor2.on?(tracking.tracking_template)

    ContactTrackings::ConversationVariables.apply!(tracking, conversation, variables.to_h)
  rescue StandardError => e
    Rails.logger.warn("[AgentTester] variables de la prueba: #{e.message}")
  end

  def find_inbox(model)
    @account.inboxes.joins('INNER JOIN channel_api ON channel_api.id = inboxes.channel_id')
            .where(channel_type: 'Channel::Api')
            .where("channel_api.additional_attributes ->> '#{MARK}' = 'true'")
            .find_by("channel_api.additional_attributes ->> 'model' = ?", model)
            &.tap { |box| ensure_model(box, model) }
  end

  def create_inbox(model)
    channel = Channel::Api.create!(account: @account, additional_attributes: { MARK => true, 'model' => model })
    @account.inboxes.create!(name: "#{INBOX_NAME} · #{model}", channel: channel).tap { |box| ensure_model(box, model) }
  end

  # El hook del bot de NUESTRA bandeja con su modelo fijo (si alguien lo cambió a mano, se repone).
  def ensure_model(box, model)
    hook = @account.hooks.find_or_initialize_by(app_id: 'tracking_bot', inbox_id: box.id)
    return if hook.persisted? && hook.status == 'enabled' && hook.settings.to_h['model_ia'] == model

    hook.update!(status: 'enabled', hook_type: 'inbox', settings: hook.settings.to_h.merge('model_ia' => model))
  end
end
