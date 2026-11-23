# frozen_string_literal: true

# Motor 2.0 — un toque del seguimiento corto (Motor2::FollowUp): si sigue sin contestar, el agente le escribe
# retomando lo pendiente y se programa el siguiente; en el último (END_STEP), el cierre sin respuesta.
class Motor2::FollowUpJob < ApplicationJob
  queue_as :default

  def perform(tracking_id, message_id, step)
    tracking = ContactTracking.find_by(id: tracking_id)
    return unless Motor2::FollowUp.waiting?(tracking, message_id)
    return Motor2::FollowUp.finish!(tracking) if step == Motor2::FollowUp::END_STEP

    message = Message.find_by(id: message_id)
    return unless message

    plan = Motor2::FollowUp.plan_for(Motor2::Config.for(tracking).function)
    # Llegó tarde (el servidor estuvo detenido) o al filo de la ventana: no se manda texto libre, pero el
    # seguimiento sigue (plantillas o cierre) en vez de quedarse colgado.
    return Motor2::FollowUp.after_window(tracking, message, plan) unless Motor2::LateMessage.window_open?(tracking.conversation)

    nudge(tracking)
    Motor2::FollowUp.next_step(tracking, message, step + 1, plan) if plan
  end

  private

  def nudge(tracking)
    text = Motor2::Attempt.new(tracking).message
    Motor2::Delivery.send_reply(tracking, tracking.conversation, text) if text.present?
  end
end
