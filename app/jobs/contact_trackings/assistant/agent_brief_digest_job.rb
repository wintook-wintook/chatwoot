# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — LEER UN ENCARGO, EN SEGUNDO PLANO
# ================================================================================
# Leer ADAM son decenas de llamadas y minutos (ver BriefDigestService): no cabe en una
# request. El controlador encola esto al subir el encargo (o al reintentar) y la
# pantalla consulta el avance real en TurnProgress y el estado en el encargo.
#
# Un encargo ya leído no se vuelve a leer: el job sale sin gastar.
# Cualquier falla deja el encargo en `failed`, con lo leído hasta ahí guardado.
# ================================================================================

class ContactTrackings::Assistant::AgentBriefDigestJob < ApplicationJob
  queue_as :default

  def perform(brief_id, user_id, turn_id = nil)
    brief = TrackingAgentBrief.find_by(id: brief_id)
    return if brief.nil? || brief.ready?

    user = User.find_by(id: user_id)
    avance = ContactTrackings::Assistant::TurnProgress.new(brief.account, user, turn_id) if user
    ContactTrackings::Assistant::BriefDigestService.new(brief, progress: avance&.method(:update)).call
  rescue StandardError => e
    Rails.logger.error "[Asistente] AgentBriefDigestJob falló: #{e.class}: #{e.message}"
    brief&.update(status: 'failed', usage: brief.usage.merge('error' => 'unexpected'))
  end
end
