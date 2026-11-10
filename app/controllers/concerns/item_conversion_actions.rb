# frozen_string_literal: true

# Tarea ↔ tarea agendada (Cases::Conversion), para los controladores de tareas (@task) y de
# tareas agendadas (@meeting): cada uno ya encontró el registro con su alcance.
#   POST …/:id/schedule  la tarea pasa a la agenda (o se agenda una sesión ligada)
#   POST …/:id/to_task   la tarea agendada sale de la agenda y queda como tarea
module ItemConversionActions
  extend ActiveSupport::Concern

  FROZEN_DEFAULT = 'Ticket cerrado: no se puede modificar. Reábrelo si necesitas cambiarlo.'

  def schedule
    frozen_conversion?(@task) || render_schedule(@task)
  end

  def to_task
    frozen_conversion?(@meeting) || render_to_task(@meeting)
  end

  private

  # true si ya respondió (caso cerrado: solo lectura).
  def frozen_conversion?(item)
    return false unless item.case_ticket&.frozen_for_edit?

    message = self.class.const_defined?(:FROZEN_MSG) ? self.class::FROZEN_MSG : FROZEN_DEFAULT
    render json: { error: message }, status: :unprocessable_entity
    true
  end

  def schedule_params
    params.permit(:title, :description, :starts_at, :ends_at, :time_zone, :location, :is_visit, :notify_client,
                  :organizer_id, :keep_task, attendee_emails: []).to_h
  end

  def render_schedule(task)
    result = Cases::Conversion.new(task, user: current_user).to_meeting(schedule_params)
    meeting = result[:meeting]
    render json: { mode: result[:mode],
                   meeting: { id: meeting.id, folio: meeting.folio, title: meeting.title, starts_at: meeting.starts_at,
                              case_ticket_id: meeting.case_ticket_id } }
  rescue Cases::Conversion::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def render_to_task(meeting)
    notify = ActiveModel::Type::Boolean.new.cast(params[:notify_client]) || false
    result = Cases::Conversion.new(meeting, user: current_user).to_task(notify_client: notify)
    task = result[:task]
    render json: { mode: result[:mode], task: { id: task.id, sequence: task.sequence, title: task.title, due_at: task.due_at,
                                                case_ticket_id: task.case_ticket_id },
                   client_notice: result[:notice] }.compact
  rescue Cases::Conversion::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end
end
