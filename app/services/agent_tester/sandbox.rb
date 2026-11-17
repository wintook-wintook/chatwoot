# frozen_string_literal: true

# Probador de agentes — el canal de pruebas: una bandeja API SIN webhook (un mensaje ahí no sale a
# ninguna parte), la misma idea que la pila de pruebas del 1.0
# (ContactTrackings::Assistant::TestBattery.sandbox_inbox). Si la cuenta no tiene, se crea
# «Probador de agentes».
#
# Cada plática de prueba es un contacto y una conversación nuevos en ese canal, con el agente
# asignado como lo asignan las automatizaciones (ActionService#assign_tracking_template). El
# cliente escribe y contesta el motor de verdad (1.0 o 2.0, según el agente), igual que con un
# cliente real. El seguimiento queda «activo» para que no salgan intentos a media prueba.
class AgentTester::Sandbox
  INBOX_NAME = 'Probador de agentes'

  def initialize(account)
    @account = account
  end

  def inbox
    @inbox ||= ContactTrackings::Assistant::TestBattery.sandbox_inbox(@account) || create_inbox
  end

  # → la conversación de prueba (nil si no se pudo asignar el agente).
  def start(template, user:)
    contact = @account.contacts.create!(name: "Probador · #{user&.name || 'prueba'} · #{template.name}".first(100))
    contact_inbox = ContactInbox.create!(contact: contact, inbox: inbox, source_id: SecureRandom.uuid)
    conversation = Conversation.create!(account: @account, inbox: inbox, contact: contact, contact_inbox: contact_inbox,
                                        status: :open, additional_attributes: { 'agent_tester' => true, 'agent_tester_user_id' => user&.id })
    same_model_as(template)
    ActionService.new(conversation).assign_tracking_template([template.id], inbox_id: inbox.id)
    tracking = tracking_for(conversation)
    return nil unless tracking

    tracking.update_columns(status: 'active', updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    conversation
  end

  def say(conversation, text)
    conversation.messages.create!(account: @account, inbox: conversation.inbox, sender: conversation.contact,
                                  message_type: :incoming, content: text.to_s.strip.first(2000))
  end

  def tracking_for(conversation) = ContactTracking.where(conversation_id: conversation.id).order(:id).last

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

  # El 1.0 elige el modelo por bandeja (ContactTrackings::EngineConfig): el canal de pruebas usa
  # el de la bandeja del agente, para contestar con el mismo modelo que en vivo.
  def same_model_as(template)
    hook = @account.hooks.find_by(app_id: 'tracking_bot', inbox_id: template.inbox_id, status: 'enabled')
    model = hook&.settings&.dig('model_ia').presence || ContactTrackings::EngineConfig::DEFAULT_MODEL
    mine = @account.hooks.find_or_initialize_by(app_id: 'tracking_bot', inbox_id: inbox.id)
    mine.update!(status: 'enabled', hook_type: 'inbox', settings: mine.settings.to_h.merge('model_ia' => model))
  rescue StandardError => e
    Rails.logger.warn("[AgentTester] modelo del canal de pruebas: #{e.message}")
  end

  def create_inbox
    channel = Channel::Api.create!(account: @account)
    @account.inboxes.create!(name: INBOX_NAME, channel: channel)
  end
end
