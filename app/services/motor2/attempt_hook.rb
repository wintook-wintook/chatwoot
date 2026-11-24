# frozen_string_literal: true

# Motor 2.0 — el desvío de los intentos. ContactTrackingJob (y su hijo TrackingDispatch::SendJob,
# el despachador de campañas) piden el texto con IA del intento a #generate_ai_message; para un
# agente 2.0 lo escribe Motor2::Attempt (nil = el job usa su mensaje simple de siempre, nunca el
# texto del 1.0). Para un agente 1.0 no cambia nada (super).
#
# Va como `prepend` (config/initializers/motor2.rb) para no editar el job del 1.0. Se engancha
# a generate_ai_message y no a generate_message porque las pruebas del 1.0 simulan
# generate_message con any_instance, que RSpec no permite sobre un método antepuesto.
module Motor2::AttemptHook
  def generate_ai_message(tracking, template_content = nil)
    return super unless Motor2.on?(tracking.tracking_template)

    Motor2::CollectionsTouch.text(tracking) || Motor2::CampaignTouch.text(tracking) || Motor2::Attempt.new(tracking).message
  end

  private

  # Sin IA en la cuenta (o si falló), el texto que escribió la empresa en la campaña sigue saliendo tal cual (no
  # necesita IA); antes salía el «Hola, te escribo para dar seguimiento…» genérico.
  def generate_simple_message(tracking)
    return super unless Motor2.on?(tracking.tracking_template)

    Motor2::CollectionsTouch.text(tracking) || Motor2::CampaignTouch.text(tracking) || super
  end
end
