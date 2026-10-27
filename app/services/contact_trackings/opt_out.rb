# frozen_string_literal: true

# ================================================================================
# prospeccion V4 — LISTA DE NO CONTACTAR (BAJA)
# ================================================================================
# Plan: docs/prospeccion_estudio.md (§9 F3, §10 V4, D11).
#
#   Cómo llega:  'link'  → el enlace del correo (/baja/:token) o la baja con un clic de Gmail
#                'reply' → respondió «no me escriban», «dame de baja», «baja», «stop»…
#                'agent' → la marcó alguien a mano
#   Qué hace:    contacts.opted_out_at / opted_out_source; cancela sus seguimientos activos.
#                Es por contacto y vale en todos los canales: ninguna campaña lo vuelve a
#                inscribir (TrackingCampaigns::Enroll → 'opted_out').
#   El enlace va firmado (signed_id, propósito :opt_out): no se puede adivinar ni alterar.
# ================================================================================
module ContactTrackings::OptOut
  SOURCES = %w[link reply agent].freeze
  ACTIVE_STATUSES = %w[pending scheduled active paused].freeze

  # Frases que piden no volver a ser contactado. «No me interesa» NO es baja: es una salida
  # del prospecto (V5), se le puede volver a buscar más adelante.
  # Solo formas de PETICIÓN («no me escriban», «no me vuelvan a contactar»): «no me escribieron
  # los precios» no es una baja.
  ASK = '(?:escrib(?:an|as|a)|contact(?:en|es|e)|env[ií](?:en|es|e)|mand(?:en|es|e))'
  INFINITIVE = '(?:escribir|contactar|enviar|mandar)'
  REQUEST = /
    \b(?:
      d[aeé]n?me\s+de\s+baja | darme\s+de\s+baja | dar\s+de\s+baja |
      (?:ya\s+)?no\s+(?:me\s+)?#{ASK}\b |
      no\s+(?:me\s+)?vuelv(?:an|as|a)\s+a\s+#{INFINITIVE}\b |
      no\s+quiero\s+(?:recibir|que\s+me\s+#{ASK}) |
      qu[ií]t[ae]n?me\s+de\s+(?:su|tu|la|esta|sus)\s+lista |
      (?:borr|elimin)\w*\s+mis\s+datos |
      unsubscribe
    )
  /xi
  ONLY_WORD = /\A\s*(?:baja|stop|alto|unsubscribe)\s*[.!¡]*\s*\z/i

  module_function

  def call(contact, source:)
    return false if contact.nil? || contact.opted_out?

    contact.update_columns(opted_out_at: Time.current, opted_out_source: source.to_s, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    contact.contact_trackings.where(status: ACTIVE_STATUSES).find_each(&:cancel!)
    Rails.logger.info "[OptOut] Contacto ##{contact.id} pidió no ser contactado (#{source})"
    true
  end

  def undo(contact)
    contact.update_columns(opted_out_at: nil, opted_out_source: nil, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  def requested_in?(text)
    text = text.to_s
    text.match?(ONLY_WORD) || text.match?(REQUEST)
  end

  def token(contact)
    contact.signed_id(purpose: :opt_out)
  end

  def contact_for(token)
    Contact.find_signed(token.to_s, purpose: :opt_out)
  end

  def url(contact)
    host = ENV.fetch('FRONTEND_URL', '').chomp('/')
    "#{host}/baja/#{token(contact)}"
  end

  # El enlace de baja para los correos que escribe un Agente IA en esa conversación (nil si no aplica).
  def url_for_conversation(conversation)
    return unless conversation&.inbox&.email? && conversation.contact
    return unless ContactTracking.exists?(conversation_id: conversation.id)

    url(conversation.contact)
  end
end
