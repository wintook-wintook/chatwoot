# frozen_string_literal: true

# ================================================================================
# @tickets_cases F3 — Espejo de una reunión en Google Calendar (plan §4.4)
# ================================================================================
# Corre FUERA del request para que agendar no dependa de la latencia de Google:
# la reunión ya está guardada en MGCI cuando este job arranca. Si Google falla,
# `GoogleMirrorService` deja la fila en `failed` con el error a la vista y el
# agente puede reintentar desde la fila ("Reintentar"), así que no reintentamos
# en bucle contra la cuota de la API.
#
# `changes` viaja para que el servicio derive el `sendUpdates` del diff (§10.2b):
# mover la fecha o cambiar invitados escribe al cliente; corregir un typo no.
# ================================================================================

class Cases::MeetingSyncJob < ApplicationJob
  queue_as :low

  def perform(meeting_id, operation = 'create', changes = nil)
    meeting = CaseMeeting.find_by(id: meeting_id)
    return if meeting.nil?

    mirror = Cases::Meetings::GoogleMirrorService.new(meeting)

    case operation.to_s
    when 'create' then mirror.create
    when 'update' then mirror.update(changes: changes)
    when 'cancel' then mirror.cancel
    end
  rescue StandardError => e
    # El servicio ya captura los errores de la API; esto es la última red para
    # que un fallo del espejo nunca tumbe nada más.
    Rails.logger.error("[GestorTickets] MeetingSyncJob #{meeting_id}: #{e.message}")
  end
end
