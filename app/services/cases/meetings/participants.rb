# frozen_string_literal: true

# Agenda — los participantes de una tarea agendada (CaseMeetingParticipant): otros usuarios del equipo, además del
# responsable (organizer). Solo en tareas agendadas (con hora); las tareas sin hora siguen con un responsable.
#
#   Cases::Meetings::Participants.sync!(meeting, user_ids, actor:)    deja exactamente esos (avisa a los nuevos y a los que salen)
#   Cases::Meetings::Participants.changed!(meeting, before, actor:)   cambió la hora o se canceló → aviso a los participantes
#   Cases::Meetings::Participants.decline!(meeting, user, note)       «No puedo ir» → aviso al responsable
#   Cases::Meetings::Participants.remind_due!                         recordatorio antes de empezar (Cases::MeetingParticipantsReminderJob)
#
# Los avisos son de la campanita (Notification «case_meeting_participant», actor: la tarea agendada). Si el participante
# tiene Google Calendar, además va como invitado del evento (Cases::Meetings::GoogleMirrorService#attendees).
module Cases::Meetings::Participants
  REMIND_BEFORE = 30.minutes

  module_function

  def sync!(meeting, user_ids, actor: nil)
    wanted = clean_ids(meeting, user_ids)
    current = meeting.participants.pluck(:user_id)
    added = wanted - current
    removed = current - wanted
    meeting.participants.where(user_id: removed).delete_all if removed.any?
    added.each { |id| meeting.participants.create!(account_id: meeting.account_id, user_id: id) }
    notify(meeting, added, 'added', actor: actor)
    notify(meeting, removed, 'removed', actor: actor)
    { added: added, removed: removed }
  end

  # Solo usuarios de la cuenta, sin el responsable (él ya la ve) y sin repetidos.
  def clean_ids(meeting, user_ids)
    ids = Array(user_ids).map(&:to_i).select(&:positive?).uniq - [meeting.organizer_id]
    ids.empty? ? [] : meeting.account.users.where(id: ids).pluck(:id)
  end

  # before: { starts_at:, status: } de antes del cambio.
  def changed!(meeting, before, actor: nil)
    kind = if meeting.cancelled? && before[:status].to_s != 'cancelled'
             'cancelled'
           elsif before[:starts_at] && meeting.starts_at != before[:starts_at]
             'rescheduled'
           end
    return unless kind

    meeting.update_columns(participants_reminded_at: nil) if kind == 'rescheduled' # rubocop:disable Rails/SkipsModelValidations
    notify(meeting, meeting.participants.where(status: 'invited').pluck(:user_id), kind, actor: actor)
  end

  def decline!(meeting, user, note)
    participant = meeting.participants.find_by!(user_id: user.id)
    participant.update!(status: 'declined', note: note.to_s.first(250).presence, responded_at: Time.current)
    notify(meeting, [meeting.organizer_id].compact, 'declined', actor: user, extra: { name: user.name, note: participant.note })
    participant
  end

  def remind_due!(now: Time.current)
    CaseMeeting.active.where(participants_reminded_at: nil, starts_at: now..(now + REMIND_BEFORE))
               .where(id: CaseMeetingParticipant.where(status: 'invited').select(:case_meeting_id)).find_each do |meeting|
      notify(meeting, meeting.participants.where(status: 'invited').pluck(:user_id), 'reminder')
      meeting.update_columns(participants_reminded_at: now) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def notify(meeting, user_ids, kind, actor: nil, extra: {})
    return if user_ids.blank?

    meta = { 'kind' => kind, 'title' => meeting.title, 'when' => when_text(meeting) }.merge(extra.transform_keys(&:to_s)).compact
    meeting.account.users.where(id: user_ids).where.not(id: actor&.id).find_each do |user|
      NotificationBuilder.new(notification_type: 'case_meeting_participant', user: user, account: meeting.account,
                              primary_actor: meeting, secondary_actor: actor, meta: meta).perform
    rescue StandardError => e
      Rails.logger.warn("[Cases::Meetings::Participants] aviso a #{user.id}: #{e.class}: #{e.message}")
    end
  end

  # [{ id, name, status, note }] para las pantallas.
  def json(meeting)
    meeting.participants.includes(:user).map { |p| { id: p.user_id, name: p.user&.name, status: p.status, note: p.note } }
  end

  def when_text(meeting)
    zone = meeting.time_zone.presence || 'America/Mexico_City'
    I18n.l(meeting.starts_at.in_time_zone(zone), format: '%d/%m/%Y %H:%M')
  rescue StandardError
    meeting.starts_at.to_s
  end
end
