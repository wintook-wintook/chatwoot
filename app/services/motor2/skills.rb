# frozen_string_literal: true

# Motor 2.0 — las habilidades. Cada una es un paquete de 5 piezas (plan §11.6): campos de la
# ficha (Motor2::Config#skill), herramientas, memoria (Motor2::State), unas líneas de
# instrucciones nuestras y pruebas (spec/services/motor2/). Mejorar una mejora a todos los
# agentes que la tienen prendida.
module Motor2::Skills
  # Áreas va primero: decide qué toca en el mensaje (y si se busca) antes que las demás.
  ALL = [
    Motor2::Skills::Areas, Motor2::Skills::Identity, Motor2::Skills::Campaign, Motor2::Skills::Knowledge, Motor2::Skills::Data,
    Motor2::Skills::Qualify, Motor2::Skills::Recommend, Motor2::Skills::Quote, Motor2::Skills::Offers,
    Motor2::Skills::Appointments, Motor2::Skills::Goal, Motor2::Skills::Tickets, Motor2::Skills::Files, Motor2::Skills::Collections,
    Motor2::Skills::Handoff, Motor2::Skills::Finish,
    Motor2::Skills::Tags
  ].freeze

  # Para el entrenador: qué hace cada una (las que se prenden en «Qué hace»).
  CATALOG = {
    'data' => 'pregunta y guarda datos del cliente', 'offers' => 'da becas, descuentos o plazos uno a la vez',
    'appointments' => 'agenda, mueve o cancela citas en Google Calendar', 'tickets' => 'levanta casos y dice cómo van',
    'files' => 'manda archivos subidos al agente', 'handoff' => 'pasa la plática a una persona',
    'qualify' => 'califica al prospecto con las preguntas de la empresa',
    'areas' => 'entiende si es soporte, comercial o administrativo y lo resuelve o lo pasa a esa área',
    'campaign' => 'despierta el interés en la oferta de la campaña y pasa el relevo a quien sigue',
    'identity' => 'sabe de qué empresa es el cliente (o se lo pregunta una vez) y lo que ya se sabe de él',
    'recommend' => 'recomienda 2 o 3 productos del Catálogo, con su precio y su foto, según lo que busca',
    'quote' => 'arma la cotización con precios del Catálogo (borrador para el vendedor o se la manda)',
    'goal' => 'lleva la plática hacia la meta de la empresa (agendar la cita o cotizar) sin presionar',
    'collections' => 'da el resumen de saldo, registra promesas de pago, «ya pagué» y aclaraciones de la cartera'
  }.freeze

  module_function

  def for(turn)
    ALL.map { |klass| klass.new(turn) }.select(&:on?)
  end
end
