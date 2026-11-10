# frozen_string_literal: true

# Cancelar una tarea o una tarea agendada (cita, llamada, visita) — «ya no se va a hacer».
# No es completarla (eso pide reporte) ni borrarla (eso es solo para errores de captura).
#   Cases::Cancellation.new(item, user:, params: { reason_id:, comment:, minutes:, scope:, notify_client: }).call
#     → { notice: nil | { sent: true } | { sent: false, reason: } }
# - Motivo del catálogo (TaskOutcome purpose: cancel); «Otro» pide comentario.
# - Tiempo dedicado: opcional; obligatorio si ya se trabajó (visita con «voy en camino» o
#   «llegué», tarea del cliente en proceso). Con tiempo queda un reporte cerrado que suma a
#   las horas del caso y sale en Reportes.
# - Tarea agendada: una o toda la serie (scope: all), también en Google Calendar; y, si se
#   pide, se le avisa al cliente por su conversación (si la ventana lo permite).
class Cases::Cancellation
  class Error < StandardError; end

  def initialize(item, user:, params: {})
    params = params.to_h.symbolize_keys
    @item = item
    @user = user
    @reason = item.account.task_outcomes.for_cancel.find_by(id: params[:reason_id])
    @comment = params[:comment].to_s.strip.presence
    @minutes = params[:minutes].to_i
    @scope = params[:scope].to_s == 'all' ? 'all' : 'one'
    @notify_client = ActiveModel::Type::Boolean.new.cast(params[:notify_client])
  end

  def call
    validate!
    ActiveRecord::Base.transaction do
      meeting? ? cancel_meeting : cancel_task
      record_time if @minutes.positive?
    end
    { notice: (notify if meeting? && @notify_client) }
  end

  def text
    [@reason&.label, @comment].compact.join(' — ').first(255)
  end

  # ¿Ya se trabajó? Entonces el tiempo es obligatorio.
  def self.work_started?(item)
    if item.is_a?(CaseMeeting)
      item.on_my_way_at.present? || item.arrived_at.present?
    else
      item.client_status == 'in_progress'
    end
  end

  private

  def meeting? = @item.is_a?(CaseMeeting)

  def validate!
    key = validation_error
    raise Error, I18n.with_locale(@item.account.locale.presence || I18n.default_locale) { I18n.t("cancellation.errors.#{key}") } if key
  end

  def validation_error
    return 'reason' unless @reason
    return 'comment' if @reason.other? && @comment.nil?
    return 'minutes' if self.class.work_started?(@item) && !@minutes.positive?

    'not_open' unless open?
  end

  def open?
    meeting? ? @item.scheduled? : @item.pending?
  end

  def cancel_task
    @item.update!(status: :cancelled, cancelled_at: Time.current, cancel_reason: text)
  end

  def cancel_meeting
    if @scope == 'all' && @item.case_meeting_series
      series = @item.case_meeting_series
      series.case_meetings.active.find_each { |m| m.update!(status: :cancelled, cancel_reason: text) }
      Cases::Meetings::GoogleMirrorService.new(@item).cancel_series(series)
      series.cancel!(actor: @user)
    else
      @item.update!(status: :cancelled, cancel_reason: text)
      Cases::MeetingSyncJob.perform_later(@item.id, 'cancel')
    end
  end

  # El tiempo que sí se dedicó: un reporte ya cerrado (suma a las horas del caso).
  def record_time
    report = TaskReport.build_for(@item, user: @user, minutes: @minutes,
                                         content: I18n.t('cancellation.report', reason: text))
    report.save!
    report.close!
  end

  def notify
    Cases::MeetingClientNotice.call(@item, @user, 'cancellation.client_message')
  end
end
