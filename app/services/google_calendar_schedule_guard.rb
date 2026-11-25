# F3b «Agendar a» (fix/calendario_google): ¿puede `viewer` poner algo en el calendario de
# Google de un compañero? Solo si el compañero le dio «Hacer cambios» (writer/owner) en Google.
# Se pregunta a Google en ese momento con la conexión de QUIEN AGENDA.
#
#   guard = GoogleCalendarScheduleGuard.new(account:, viewer:, agent_id:).call
#   guard.ok?            → true / false
#   guard.error          → motivo legible (I18n) si no se puede
#   guard.coworker_integration / guard.viewer_integration
class GoogleCalendarScheduleGuard
  attr_reader :error, :reason, :coworker_integration, :viewer_integration

  # allow_without_google: si el compañero no tiene Google no hay calendario que invadir
  # (tarea agendada que solo vive en el sistema) → se deja pasar.
  def initialize(account:, viewer:, agent_id:, allow_without_google: false)
    @account = account
    @viewer = viewer
    @agent_id = agent_id.to_i
    @allow_without_google = allow_without_google
  end

  def call
    @reason = find_reason
    @error = @reason && I18n.t("google_calendar_schedule.#{@reason}")
    self
  end

  def ok?
    @reason.nil?
  end

  private

  def find_reason
    return 'agent_not_found' unless @account.users.exists?(id: @agent_id)

    @coworker_integration = UserCalendarIntegration.find_by(account: @account, user_id: @agent_id)
    return (@allow_without_google ? nil : 'agent_not_connected') unless @coworker_integration

    @viewer_integration = UserCalendarIntegration.find_by(account: @account, user_id: @viewer.id)
    return 'viewer_not_connected' unless @viewer_integration
    return 'same_google' if @coworker_integration.google_email.to_s.casecmp?(@viewer_integration.google_email.to_s)

    permitted? ? nil : 'no_permission'
  end

  def permitted?
    GoogleCalendarCoworkerService.new(
      viewer_integration: @viewer_integration,
      viewer_service: GoogleCalendarService.new(@viewer_integration)
    ).can_schedule?(@coworker_integration)
  rescue StandardError
    false
  end
end
