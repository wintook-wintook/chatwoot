# Visitas — el supervisor cambia de persona o de hora una visita. Si cambia de persona,
# el evento pasa a su calendario: se cancela en el de antes y se crea en el nuevo.
class Field::VisitMover
  def initialize(meeting, user, starts_at)
    @meeting = meeting
    @user = user
    @starts_at = starts_at
  end

  def call
    other_person = @meeting.organizer_id != @user.id
    release_google_event if other_person
    @meeting.update!(changes)
    return Cases::MeetingSyncJob.perform_later(@meeting.id, 'create') if other_person

    Cases::MeetingSyncJob.perform_later(@meeting.id, 'update', @meeting.saved_changes.except('updated_at'))
  end

  private

  def release_google_event
    return if @meeting.google_event_id.blank?

    Cases::Meetings::GoogleMirrorService.new(@meeting).cancel
    @meeting.google_event_id = nil
  end

  def changes
    attrs = { organizer: @user }
    return attrs unless @starts_at

    length = @meeting.ends_at - @meeting.starts_at
    attrs.merge(starts_at: @starts_at, ends_at: @starts_at + length)
  end
end
