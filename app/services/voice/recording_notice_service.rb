# frozen_string_literal: true

# ================================================================================
# diag/llamadas_whatsapp (F7, P1) — AVISO AL CLIENTE DE QUE LA LLAMADA SE GRABA
# ================================================================================
# Cuando una llamada con grabación pasa a «en curso» (el agente contestó una entrante, o
# el cliente contestó una saliente) se le manda al cliente un mensaje normal de WhatsApp
# con el aviso: el texto de la bandeja (provider_config['recording_notice']) o el de
# siempre. El agente además ve en la ventana de llamada el guion para decirlo en voz.
#
# Una sola vez por llamada (meta.recording_notice_sent_at). Si no se puede mandar (p. ej.
# la ventana de 24 h está cerrada en una saliente) la llamada sigue igual: solo se registra.
# ================================================================================
class Voice::RecordingNoticeService
  pattr_initialize [:call!, :agent]

  def perform
    return unless call.recording_enabled? && call.in_progress?
    return if call.meta['recording_notice_sent_at'].present?

    call.merge_meta!('recording_notice_sent_at' => Time.zone.now.to_i)
    send_notice
  rescue StandardError => e
    Rails.logger.warn "[WHATSAPP CALL] no se pudo mandar el aviso de grabación (call #{call.id}): #{e.message}"
  end

  def notice_text
    propio = call.inbox.channel.try(:provider_config).to_h['recording_notice'].to_s.strip
    return propio if propio.present?

    I18n.with_locale(call.account.locale.presence || I18n.default_locale) do
      I18n.t('conversations.messages.whatsapp.call_recording_notice')
    end
  end

  private

  def send_notice
    call.conversation.messages.create!(
      account_id: call.account_id, inbox_id: call.inbox_id, message_type: :outgoing,
      sender: agent || call.accepted_by_agent, content: notice_text
    )
  end
end
