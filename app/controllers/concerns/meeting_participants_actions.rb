# frozen_string_literal: true

# Agenda — participantes de una tarea agendada en los controladores (case_meetings y agenda_items):
#   sync_meeting_participants(meeting, ids)   deja esos participantes (y reenvía el evento de Google si cambiaron)
#   notifying_participants(meeting) { … }     corre el cambio y avisa si cambió la hora o se canceló
#   participants_json(meeting)                [{ id, name, status, note }]
#   POST …/:id/decline { note }                «No puedo ir» (solo un participante; le llega al responsable)
module MeetingParticipantsActions
  extend ActiveSupport::Concern

  def decline
    meeting = Current.account.case_meetings.find(params[:id])
    return render(json: { error: 'No participas en esta tarea.' }, status: :forbidden) unless meeting.participant?(current_user)

    Cases::Meetings::Participants.decline!(meeting, current_user, params[:note])
    Cases::MeetingSyncJob.perform_later(meeting.id, 'update', { 'participants' => true }) if meeting.google_event_id.present?
    render json: { participants: participants_json(meeting.reload) }
  end

  private

  def sync_meeting_participants(meeting, ids)
    result = Cases::Meetings::Participants.sync!(meeting, ids, actor: current_user)
    return unless meeting.google_event_id.present? && (result[:added] + result[:removed]).any?

    Cases::MeetingSyncJob.perform_later(meeting.id, 'update', { 'participants' => true })
  end

  def notifying_participants(meeting)
    before = { starts_at: meeting.starts_at, status: meeting.status }
    result = yield
    Cases::Meetings::Participants.changed!(meeting, before, actor: current_user)
    result
  end

  def participants_json(meeting) = Cases::Meetings::Participants.json(meeting)
end
