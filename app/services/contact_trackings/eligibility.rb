# frozen_string_literal: true

# ================================================================================
# @campanas_vendedor / proyecto@bulk_tracking_assign
# ================================================================================
# Mixin: ContactTrackings::Eligibility
# Descripción: Reglas compartidas para clasificar contactos en una asignación
#              masiva. Lo usan tanto BulkAssignService (creación real) como
#              BulkAssignPreviewService (dry-run) para que la clasificación NO
#              diverja entre el preview y lo que realmente ejecuta el bulk.
#
# Refleja lo que haría ContactInboxBuilder al crear el contact_inbox: si no se
# puede generar el source_id para el canal, el contacto es "no contactable".
# ================================================================================

module ContactTrackings::Eligibility
  ACTIVE_STATUSES = %w[pending scheduled active paused].freeze

  # Canales que requieren teléfono (mismo criterio que ContactInboxBuilder).
  PHONE_CHANNELS = %w[Channel::Whatsapp Channel::Sms Channel::TwilioSms].freeze
  # Canales que requieren correo.
  EMAIL_CHANNELS = %w[Channel::Email].freeze
  # Canales donde el source_id se autogenera (siempre se puede crear contact_inbox).
  GENERATED_ID_CHANNELS = %w[Channel::Api Channel::WebWidget].freeze

  # Motivos de "no contactable" (claves i18n en el front).
  REASON_NO_PHONE = 'NO_PHONE'
  REASON_NO_EMAIL = 'NO_EMAIL'
  REASON_UNSUPPORTED_CHANNEL = 'UNSUPPORTED_CHANNEL'

  # Devuelve [contactable?(Boolean), reason(String|nil)].
  #   reusable: true cuando el contacto ya tiene una conversación en ese inbox,
  #   en cuyo caso el bulk reutiliza la conversación y no invoca ContactInboxBuilder.
  def channel_contactability(contact, channel_type, reusable: false)
    return [true, nil] if reusable

    if PHONE_CHANNELS.include?(channel_type)
      contact.phone_number.present? ? [true, nil] : [false, REASON_NO_PHONE]
    elsif EMAIL_CHANNELS.include?(channel_type)
      contact.email.present? ? [true, nil] : [false, REASON_NO_EMAIL]
    elsif GENERATED_ID_CHANNELS.include?(channel_type)
      [true, nil]
    else
      [false, REASON_UNSUPPORTED_CHANNEL]
    end
  end

  # IDs de contactos (de la lista dada) con un seguimiento activo en el inbox.
  def active_tracking_contact_ids(inbox_id, contact_ids)
    return Set.new if contact_ids.blank?

    ContactTracking.where(inbox_id: inbox_id, contact_id: contact_ids, status: ACTIVE_STATUSES)
                   .distinct.pluck(:contact_id).to_set
  end

  # IDs de contactos (de la lista dada) que ya tienen una conversación en el inbox.
  def contacts_with_conversation_ids(inbox_id, contact_ids)
    return Set.new if contact_ids.blank?

    Conversation.where(inbox_id: inbox_id, contact_id: contact_ids)
                .distinct.pluck(:contact_id).to_set
  end
end
