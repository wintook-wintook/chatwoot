# frozen_string_literal: true

# ================================================================================
# @tickets_cases F7 — Receptor del push de Google Calendar (plan §12.3)
# ================================================================================
# POST /google_calendar/notifications   (público, sin auth de sesión)
#
# El ping de Google **llega vacío**: solo encabezados. No dice qué cambió, así que
# aquí no se procesa nada — se responde 200 de inmediato y se encola el trabajo.
# Procesar dentro del request hace que Google reintente con backoff y llegue el
# mismo aviso varias veces (§12.7.1).
#
# Seguridad: el endpoint es público, así que el ping se autentica con el
# `X-Goog-Channel-Token` que registramos al abrir el canal. Token que no coincide
# → **404**, sin revelar nada.
# ================================================================================

class GoogleCalendarNotificationsController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  def create
    integration = UserCalendarIntegration.find_by(push_channel_id: channel_id)
    return head :not_found if integration.nil? || !valid_token?(integration)

    # `sync` es el saludo al crear el canal, no un cambio: ignorarlo o se dispara
    # un resync inútil por cada canal (§12.7.2).
    return head :ok if resource_state == 'sync'

    Cases::CalendarPushJob.perform_later(integration.id)
    head :ok
  end

  private

  def channel_id
    request.headers['X-Goog-Channel-ID'].presence
  end

  def resource_state
    request.headers['X-Goog-Resource-State'].to_s
  end

  # Comparación en tiempo constante: el token es un secreto.
  def valid_token?(integration)
    token = request.headers['X-Goog-Channel-Token'].to_s
    stored = integration.push_channel_token.to_s
    stored.present? && ActiveSupport::SecurityUtils.secure_compare(token, stored)
  rescue ArgumentError
    false
  end
end
