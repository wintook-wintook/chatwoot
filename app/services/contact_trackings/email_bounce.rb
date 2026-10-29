# frozen_string_literal: true

# ================================================================================
# prospeccion V7b — EL CORREO REBOTÓ
# ================================================================================
# Plan: docs/prospeccion_estudio.md (§10.8 V7). El aviso de no entrega (DSN: multipart/report,
# report-type=delivery-status) llega por IMAP a la bandeja. Chatwoot lo tiraba en silencio
# (IncomingEmailValidityHelper, su TODO); ahora, antes de tirarlo:
#
#   Action: failed + Status 5.x.x (definitivo)  → contacts.email_bounced_at / email_bounce_reason,
#                                                 cancela sus seguimientos en bandejas de CORREO
#                                                 (salida «bounced» en el embudo) y deja una nota
#                                                 en la conversación
#   Action: delayed / Status 4.x.x (temporal)   → nada, como antes (el servidor reintenta)
#
# Es del correo, no del contacto: su WhatsApp sigue. Ninguna campaña por correo lo vuelve a
# inscribir (ContactTrackings::Eligibility → INVALID_EMAIL) hasta que le cambien el correo.
# ================================================================================
module ContactTrackings::EmailBounce
  ACTIVE_STATUSES = %w[pending scheduled active paused].freeze
  REASON_LIMIT = 255

  module_function

  # true si era un rebote definitivo: quien llama ya no lo procesa como mensaje.
  def handle(mail, inbox)
    return false unless hard_bounce?(mail)

    contact = inbox.account.contacts.from_email(recipient(mail)) if recipient(mail).present?
    mark(contact, reason(mail)) if contact && !contact.email_bounced?
    true
  end

  def hard_bounce?(mail)
    mail.bounced? && mail.error_status.to_s.start_with?('5')
  rescue StandardError
    false
  end

  # «rfc822; juan@x.com» → «juan@x.com»
  def recipient(mail)
    mail.final_recipient.to_s.split(';').last.to_s.strip.downcase
  end

  def reason(mail)
    "#{mail.error_status} #{mail.diagnostic_code}".squish.truncate(REASON_LIMIT)
  end

  def mark(contact, reason)
    contact.update_columns(email_bounced_at: Time.current, email_bounce_reason: reason, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    active = contact.contact_trackings.joins(:inbox).where(status: ACTIVE_STATUSES, inboxes: { channel_type: 'Channel::Email' })
    active.find_each do |tracking|
      tracking.update_column(:prospect_exit, 'bounced') # rubocop:disable Rails/SkipsModelValidations
      tracking.cancel!
      note(tracking, contact, reason)
    end
    Rails.logger.info "[EmailBounce] Contacto ##{contact.id}: rebotó #{contact.email} (#{reason})"
  end

  def note(tracking, contact, reason)
    conversation = tracking.conversation
    return unless conversation

    conversation.messages.create!(account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :activity,
                                  content: "📭 El correo a #{contact.email} rebotó: #{reason}. Se detuvo el seguimiento.")
  end
end
