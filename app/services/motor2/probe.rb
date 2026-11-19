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
    config = Motor2::Config.new(@template)
    result = Motor2::Runner.new(config, state: @state, history: @messages, welcome: first_welcome(config)).call
    return { error: result.error, trace: result.trace } if result.error

    { reply: result.reply, decision: result.decision, trace: result.trace, state: @state.to_h,
      files: result.attachments.pluck(:name) }
  end

  private

  # Como con un cliente: la bienvenida combinada va en la primera respuesta (agentes de una función).
  def first_welcome(config)
    return nil unless config.function && config.welcome.present?

    @messages.none? { |m| m.to_h.symbolize_keys[:role].to_s == 'assistant' } ? config.welcome : nil
  end
end
