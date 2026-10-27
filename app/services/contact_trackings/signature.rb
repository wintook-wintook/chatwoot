# frozen_string_literal: true

# ================================================================================
# prospeccion V1 — CÓMO TERMINA EL TEXTO QUE ESCRIBE EL AGENTE IA
# ================================================================================
# Plan: docs/prospeccion_estudio.md (§9 F2, §10 V1).
#
#   WhatsApp, Telegram, etc.  → texto + marca de siempre (« #IA» el toque, «-TB» la respuesta)
#   Correo                    → texto + firma del agente (sin marca) + pie de baja (prospeccion V4)
#
# Nadie lee las marcas; en correo delatan el envío automático. Quién escribió ya lo dice
# el remitente (el usuario bot) y, en las respuestas, content_attributes[:sentiment_auto_reply].
# ================================================================================
module ContactTrackings::Signature
  module_function

  def apply(text, tracking, marker = '')
    return text if text.blank?
    return "#{text}#{marker}" unless tracking.inbox&.email?

    signature = tracking.tracking_template&.email_signature.to_s.strip
    [text, signature.presence, opt_out_footer(tracking)].compact.join("\n\n")
  end

  # prospeccion V4: todo correo del agente lleva cómo darse de baja.
  def opt_out_footer(tracking)
    return if tracking.contact.nil?

    I18n.with_locale(tracking.account&.locale.presence || I18n.default_locale) do
      I18n.t('contact_trackings.opt_out_footer', url: ContactTrackings::OptOut.url(tracking.contact))
    end
  end
end
