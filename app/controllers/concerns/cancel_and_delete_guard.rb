# frozen_string_literal: true

# Cancelar y borrar tareas y tareas agendadas — dos acciones distintas:
#   cancelar  «ya no se va a hacer»: con motivo (Cases::Cancellation), queda el historial
#   borrar    solo para errores de captura: quien la creó, en las primeras 24 h, o un administrador
module CancelAndDeleteGuard
  extend ActiveSupport::Concern

  DELETE_WINDOW = 24.hours

  private

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
