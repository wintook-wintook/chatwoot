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
    return unless message && Time.current < message.created_at + 24.hours

    nudge(tracking)
    plan = Motor2::FollowUp.plan_for(Motor2::Config.for(tracking).function)
    Motor2::FollowUp.next_step(tracking, message, step + 1, plan) if plan
  end

  private

  def nudge(tracking)
    text = Motor2::Attempt.new(tracking).message
    Motor2::Delivery.send_reply(tracking, tracking.conversation, text) if text.present?
  end
end
