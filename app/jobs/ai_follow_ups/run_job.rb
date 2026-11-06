# frozen_string_literal: true

# Seguimiento IA — corre un turno del agente (ver AiFollowUps::Runner).
#   trigger: 'scheduled' (le toca escribir; si aún no le ha escrito, es el primer mensaje) o 'reply'.
#   El Runner revisa adentro del candado que de verdad le toque.
class AiFollowUps::RunJob < ApplicationJob
  queue_as :default

  def perform(follow_up_id, trigger = 'scheduled')
    follow_up = AiFollowUp.find_by(id: follow_up_id)
    return unless follow_up&.status == 'active'

    AiFollowUps::Runner.new(follow_up, trigger: trigger).call
  end
end
