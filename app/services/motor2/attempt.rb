# frozen_string_literal: true

# Motor 2.0 — el texto de un intento cuando el cliente no ha contestado (ventana abierta). Lo
# llama ContactTrackingJob#generate_message (Motor2::AttemptHook) para los agentes 2.0; las plantillas, los tiempos y
# el despachador de campañas siguen siendo los del 1.0. Si el modelo no da nada, nil (el job usa
# su mensaje simple de siempre).
class Motor2::Attempt
  def initialize(tracking)
    @tracking = tracking
    @config = Motor2::Config.new(tracking.tracking_template)
  end

  def message
    state = Motor2::State.new(@tracking.motor2_state)
    result = Motor2::Runner.new(@config, state: state, conversation: @tracking.conversation, tracking: @tracking,
                                         mode: :attempt, attempt: [@tracking.attempt_count + 1, @tracking.max_attempts]).call
    if result.error
      Rails.logger.error("[Motor2] intento del seguimiento ##{@tracking.id}: #{result.error}")
      return
    end

    @tracking.update_columns(motor2_state: state.to_h) # rubocop:disable Rails/SkipsModelValidations
    result.reply.presence
  end
end
