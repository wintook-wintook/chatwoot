# frozen_string_literal: true

# Motor 2.0 — al pasar la plática a una persona (los tres agentes listos), el plazo para que alguien le escriba
# (attend_hours, en horas hábiles de la bandeja). Si nadie le escribe a tiempo, TrackingCampaigns::HandoffSweepJob
# deja una nota con @mención al responsable y, al triple, avisa a los administradores.
module Motor2::AttendClock
  module_function

  def start(tracking, conversation, function)
    hours = function.respond_to?(:attend_hours) ? function.attend_hours : 0
    return unless hours.positive? && conversation

    now = Time.current
    clock = TrackingCampaigns::BusinessClock.new(conversation.inbox)
    tracking.update_columns(handed_off_at: now, handoff_due_at: clock.add(now, hours), handoff_escalate_at: clock.add(now, hours * 3), # rubocop:disable Rails/SkipsModelValidations
                            updated_at: now)
  end
end
