# frozen_string_literal: true

# Motor 2.0 — las habilidades. Cada una es un paquete de 5 piezas (plan §11.6): campos de la
# ficha (Motor2::Config#skill), herramientas, memoria (Motor2::State), unas líneas de
# instrucciones nuestras y pruebas (spec/services/motor2/). Mejorar una mejora a todos los
# agentes que la tienen prendida.
module Motor2::Skills
  ALL = [
    Motor2::Skills::Knowledge, Motor2::Skills::Data, Motor2::Skills::Handoff, Motor2::Skills::Finish
  ].freeze

  module_function

  def for(turn)
    ALL.map { |klass| klass.new(turn) }.select(&:on?)
  end
end
