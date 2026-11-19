# frozen_string_literal: true

# Motor 2.0 — atender a quien escribe a una bandeja, sin automatización (§11.14.5, P1). Viene de
# ReadyAgents::Router: el agente principal de la bandeja (tracking_templates.attending +
# attend_inbox_ids) toma la conversación si:
#   - la conversación nunca ha tenido un agente (ningún contact_tracking, de ningún estado): si ya
#     tuvo uno, o lo tiene por campaña o automatización, manda ese (gana el más específico, §11.9);
#   - el contacto no tiene otro seguimiento vivo en esa bandeja;
#   - ninguna persona del equipo le ha escrito al cliente.
# Al tomarla crea el contact_tracking del agente, activo y sin intentos: no persigue al cliente,
# solo contesta. Si el agente es de «Atención a prospectos» y quien escribe ya es cliente, se lo
# pasa a su responsable y no lo atiende (Motor2::Functions::ProspectOutcomes#client!).
module Motor2::InboxRouter
  # Sin intentos: el seguimiento queda «activo» (ContactTrackingJob no corre intentos en activo) y
  # con fecha lejana, para que nadie lo tome por pendiente.
  NO_ATTEMPTS = 10.years
  LIVE = %w[pending scheduled active paused].freeze

  module_function

  # El agente que debe tomar la conversación de este mensaje, o nil.
  def agent_for(message)
    conversation = message.conversation
    return if conversation.nil? || conversation.internal?

    template = principal(conversation.account_id, conversation.inbox_id)
    return unless template
    return if ContactTracking.exists?(conversation_id: conversation.id)
    return if ContactTracking.exists?(contact_id: conversation.contact_id, inbox_id: conversation.inbox_id, status: LIVE)
    return if person_wrote?(conversation)

    template
  end

  def takes?(message)
    message.incoming? && agent_for(message).present?
  rescue StandardError => e
    Rails.logger.error("[Motor2::InboxRouter] #{e.message}")
    false
  end

  # El agente 2.0 prendido que atiende esa bandeja (uno por bandeja).
  def principal(account_id, inbox_id)
    return if inbox_id.blank?

    TrackingTemplate.where(account_id: account_id, engine: Motor2::ENGINE, attending: true, archived_at: nil)
                    .where(':id = ANY(attend_inbox_ids)', id: inbox_id.to_i).order(:id).first
  end

  # Crea el seguimiento del agente en la conversación. Regresa el seguimiento activo, o nil si
  # quien escribe ya es cliente (se pasó a su responsable) o no se pudo crear.
  def start(template, message)
    conversation = message.conversation
    tracking = ContactTracking.create!(attributes(template, conversation))
    function = Motor2::Config.new(template).function
    return tracking unless function.respond_to?(:only_prospects?) && function.only_prospects? &&
                           Motor2::ClientCheck.client?(conversation.contact)

    function.outcomes(tracking, conversation).client!
    nil
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
    Rails.logger.error("[Motor2::InboxRouter] no se pudo empezar en la conversación #{conversation&.id}: #{e.message}")
    nil
  end

  def attributes(template, conversation)
    { account: conversation.account, contact: conversation.contact, conversation: conversation, inbox_id: conversation.inbox_id,
      tracking_template: template, objective: template.objective, ai_context: template.objective, status: 'active',
      max_attempts: 1, scheduled_for: NO_ATTEMPTS.from_now, keyword_actions: Array(template.keyword_actions) }
  end

  def person_wrote?(conversation)
    conversation.messages.where(message_type: :outgoing, private: false, sender_type: 'User')
                .where("COALESCE(#{AiFollowUp.message_attr_sql('ai_agent')}, '') <> 'true'").exists?
  end
end
