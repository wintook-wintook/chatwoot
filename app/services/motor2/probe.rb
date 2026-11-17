# frozen_string_literal: true

# Motor 2.0 — el chat de prueba: el usuario es el cliente y el agente contesta con lo que hay en
# la pantalla. No guarda ni manda nada; la memoria del cliente (datos, escalón de oferta, cita)
# va y viene con la pantalla. Regresa también qué hizo el agente (la traza) para enseñarla bajo
# cada respuesta.
class Motor2::Probe
  def initialize(template, messages:, state: {})
    @template = template
    @messages = messages
    @state = Motor2::State.new(state)
  end

  def call
    result = Motor2::Runner.new(Motor2::Config.new(@template), state: @state, history: @messages).call
    return { error: result.error, trace: result.trace } if result.error

    { reply: result.reply, decision: result.decision, trace: result.trace, state: @state.to_h,
      files: result.attachments.pluck(:name) }
  end
end
