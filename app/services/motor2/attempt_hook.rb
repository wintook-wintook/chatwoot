# frozen_string_literal: true

# Motor 2.0 — el desvío de los intentos. ContactTrackingJob (y su hijo TrackingDispatch::SendJob,
# el despachador de campañas) piden el texto del intento a #generate_message; para un agente 2.0
# lo escribe Motor2::Attempt y, si el modelo no da nada, el mensaje simple de siempre. Para un
# agente 1.0 no cambia nada (super).
#
# Va como `prepend` (config/initializers/motor2.rb) para no editar el job del 1.0.
module Motor2::AttemptHook
  def generate_message(tracking, template_content = nil)
    return super unless Motor2.on?(tracking.tracking_template)

    ContactTrackings::Signature.apply(Motor2::Attempt.new(tracking).message || generate_simple_message(tracking), tracking)
  end
end
