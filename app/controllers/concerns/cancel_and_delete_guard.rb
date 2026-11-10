# frozen_string_literal: true

# Cancelar y borrar tareas y tareas agendadas — dos acciones distintas:
#   cancelar  «ya no se va a hacer»: con motivo (Cases::Cancellation), queda el historial
#   borrar    solo para errores de captura: quien la creó, en las primeras 24 h, o un administrador
module CancelAndDeleteGuard
  extend ActiveSupport::Concern

  DELETE_WINDOW = 24.hours
  # Una tarea concluida o cancelada es de solo lectura: solo se reabre (status pending)
  # o se le mueve el orden en la lista.
  CLOSED_TASK_KEYS = %w[status position].freeze

  private

  # before_action del update de tareas (@task y sus parámetros en task_edit_attrs).
  def lock_closed_task
    return unless @task && (@task.done? || @task.cancelled?)
    return if reopen_only?(task_edit_attrs.stringify_keys)

    render json: { error: I18n.t('cancellation.closed_locked') }, status: :unprocessable_entity
  end

  def reopen_only?(attrs)
    attrs['status'].to_s.in?(['', 'pending']) && (attrs.keys - CLOSED_TASK_KEYS).empty?
  end

  # Lo que se quiere cambiar: el hash case_task (tareas del caso) o los campos sueltos
  # (tareas rápidas, sin caso).
  def task_edit_attrs
    raw = params[:case_task]
    raw = params.except(:controller, :action, :id, :account_id, :format, :quick_task) unless raw.is_a?(ActionController::Parameters)
    raw.to_unsafe_h
  end

  # true si ya respondió (no se puede borrar).
  def delete_restricted?(record, creator_id)
    return false if access_grant.admin?
    return false if creator_id == current_user.id && record.created_at > DELETE_WINDOW.ago

    render json: { error: I18n.t('cancellation.delete_restricted'), cancel_instead: true }, status: :forbidden
    true
  end

  def cancellation_params
    params.permit(:reason_id, :comment, :minutes, :scope, :notify_client).to_h
  end

  # → el resultado de Cases::Cancellation o nil si ya respondió con el error.
  def run_cancellation(item)
    Cases::Cancellation.new(item, user: current_user, params: cancellation_params).call
  rescue Cases::Cancellation::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
    nil
  end
end
