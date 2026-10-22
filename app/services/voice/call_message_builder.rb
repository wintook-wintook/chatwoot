# frozen_string_literal: true

# ================================================================================
# diag/llamadas_whatsapp (F3) — LA BURBUJA DE LA LLAMADA EN LA CONVERSACIÓN
# ================================================================================
# Un mensaje content_type voice_call con los datos en content_attributes.data:
#   { call_id, call_sid, call_source, call_direction, status, accepted_by, duration_seconds }
# Entrante: del contacto. Saliente: del agente que llamó. No se envía al cliente ni la
# ven bots ni seguimientos (Message#voice_call?, D6). Se crea directo en la conversación:
# Messages::MessageBuilder no guarda content_attributes.data.
# Portado de la v4.19 (enterprise/app/services/voice/call_message_builder.rb).
# ================================================================================
class Voice::CallMessageBuilder
  pattr_initialize :call

  def perform!
    call.message || create_message!
  end

  def update_status!(status:, agent: nil, duration_seconds: nil)
    message = call.message
    return unless message

    patch = { 'status' => status.to_s.tr('_', '-'),
              'accepted_by' => agent && { 'id' => agent.id, 'name' => agent.available_name },
              'duration_seconds' => duration_seconds }.compact
    datos = (message.content_attributes['data'] || {}).merge(patch)
    message.update!(content_attributes: message.content_attributes.merge('data' => datos))
    message
  end

  private

  def create_message!
    call.conversation.messages.create!(
      account_id: call.account_id, inbox_id: call.inbox_id,
      message_type: call.outgoing? ? :outgoing : :incoming,
      sender: call.outgoing? ? call.accepted_by_agent : call.contact,
      content: I18n.t('conversations.messages.voice_call.whatsapp'),
      content_type: :voice_call,
      content_attributes: { 'data' => data_payload }
    )
  end

  def data_payload
    { 'call_id' => call.id, 'call_sid' => call.provider_call_id, 'call_source' => call.provider,
      'call_direction' => call.direction_label, 'status' => call.display_status }
  end
end
