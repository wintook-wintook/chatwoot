# fix/calendario_eliminar F1 — «Eliminar evento» desde el calendario (eventos de Google SIN tarea).
#
#   result = GoogleCalendarEventDeleter.new(account:, user:, service:, event_id:,
#                                           options: { calendar_id:, scope: 'one' | 'all', notify: true }).call
#   result.ok / result.reason / result.scope
#
# Reglas (plan §3.2 y F0):
# - Un evento ligado a una tarea agendada (o a su serie) NO se borra aquí: se cancela la tarea
#   y ella quita su evento → reason 'linked_to_agenda_item'.
# - De una serie: «Solo este» marca la ocurrencia como cancelada (como las tareas agendadas);
#   «Toda la serie» borra el maestro (recurringEventId).
# - Solo el organizador avisa a los invitados (sendUpdates=all). Si me invitaron, solo se quita
#   de MI calendario y nunca se avisa.
# - Si ya no estaba (404/410) se toma como hecho.
# - D3: si era la cita que agendó el bot de seguimientos, se libera la cita del seguimiento y
#   queda nota privada en la conversación (sin escribirle al cliente).
class GoogleCalendarEventDeleter
  Result = Struct.new(:ok, :reason, :scope, keyword_init: true)

  def initialize(account:, user:, service:, event_id:, options: {})
    @account = account
    @user = user
    @service = service
    @event_id = event_id.to_s
    @calendar_id = options[:calendar_id].presence || 'primary'
    @whole_series_asked = options[:scope].to_s == 'all'
    @notify = options.fetch(:notify, true)
  end

  def call
    event = @service.get_event(@event_id, calendar_id: @calendar_id)
    return done('one') unless event.is_a?(Hash)

    series_id = event['recurringEventId'].presence
    return failure('linked_to_agenda_item') if linked_to_agenda_item?([@event_id, series_id].compact)

    whole_series = whole_series?(series_id)
    remove(series_id, whole_series, send_updates(event))
    release_bot_appointments([@event_id, (series_id if whole_series)].compact)
    done(whole_series ? 'all' : 'one')
  rescue StandardError => e
    Rails.logger.warn "[GoogleCalendarEventDeleter] user #{@user.id} event #{@event_id}: #{e.message}"
    failure(e.message.include?('error 403') ? 'no_permission' : 'google_error')
  end

  private

  def whole_series?(series_id) = @whole_series_asked && series_id.present?

  def remove(series_id, whole_series, updates)
    if whole_series
      @service.delete_event(series_id, calendar_id: @calendar_id, send_updates: updates)
    elsif series_id
      @service.cancel_instance(@event_id, calendar_id: @calendar_id, send_updates: updates)
    else
      @service.delete_event(@event_id, calendar_id: @calendar_id, send_updates: updates)
    end
  end

  def send_updates(event)
    event.dig('organizer', 'self') == true && @notify ? 'all' : 'none'
  end

  def linked_to_agenda_item?(ids)
    @account.case_meetings.exists?(google_event_id: ids) ||
      CaseMeetingSeries.exists?(account_id: @account.id, google_event_id: ids)
  end

  def release_bot_appointments(ids)
    ContactTracking.where(account_id: @account.id, appointment_event_id: ids).find_each do |tracking|
      tracking.update!(
        appointment_at: nil, appointment_event_id: nil, appointment_calendar_id: nil, appointment_calendar_gid: nil,
        ai_context: "#{tracking.ai_context}\n\n🗑️ [CITA ELIMINADA] #{@user.name} eliminó la cita desde el calendario."
      )
      private_note(tracking)
    end
  rescue StandardError => e
    # El evento ya se borró: que esto no lo reporte como fallido.
    Rails.logger.warn "[GoogleCalendarEventDeleter] liberar cita del bot (#{ids.join(',')}): #{e.message}"
  end

  def private_note(tracking)
    conversation = tracking.conversation_id && @account.conversations.find_by(id: tracking.conversation_id)
    return unless conversation

    Messages::MessageBuilder.new(
      @user, conversation,
      { message_type: 'outgoing', private: true, content: I18n.t('google_calendar_delete.bot_note', name: @user.name) }
    ).perform
  rescue StandardError => e
    Rails.logger.warn "[GoogleCalendarEventDeleter] nota privada del seguimiento #{tracking.id}: #{e.message}"
  end

  def done(scope) = Result.new(ok: true, scope: scope)

  def failure(reason) = Result.new(ok: false, reason: reason)
end
