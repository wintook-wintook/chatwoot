# frozen_string_literal: true

# «Pasar a una persona» — cuándo (campo de la ficha) y a quién (usuario o equipo). Al pasarlo,
# el agente se despide, deja una nota privada con el motivo, asigna la conversación y se pausa.
#
#   skills.handoff = { 'on' => true, 'when' => 'pide hablar con alguien o se molesta',
#                      'user_id' => 3, 'team_id' => nil }
class Motor2::Skills::Handoff < Motor2::Skills::Base
  DEFAULT_WHEN = 'pide hablar con una persona, se molesta, o pide algo que no puedes resolver con lo que sabes'

  def self.key = 'handoff'

  def tools
    return [] if area_channels?

    props = { motivo: STR }
    props[:temperatura] = Motor2::Skills::Qualify::TEMPERATURE if config.skill_on?(:qualify)
    [fn('pasar_a_humano', "Pásalo a una persona del equipo cuando: #{when_text}. Después escribe solo la despedida.",
        props, %w[motivo])]
  end

  def instructions = "- Pasa a una persona (pasar_a_humano) cuando: #{when_text}."

  def call(_name, args)
    if hold?
      return { error: 'La empresa pidió terminar primero: dile que con gusto lo pasas y haz las preguntas que faltan ' \
                      '(si lo vuelve a pedir, entonces sí lo pasas).' }
    end

    Motor2::Skills::Qualify.note_temperature(state, args['temperatura'])
    areas = @turn.find_skill('areas')
    state['handoff_area'] ||= areas.area_key if areas && areas.area_key != 'none'
    @turn.decide('handoff', args['motivo'])
    { ok: true, nota: 'Listo. Ahora escribe solo la despedida para el cliente: dile que una persona le sigue.' }
  end

  private

  # «Pide una persona» con «terminar primero» (Motor2::Skills::QualifyFlow#hold_handoff?).
  def hold?
    flow = @turn.flow_skill
    flow.respond_to?(:hold_handoff?) && flow.hold_handoff?
  end

  def when_text = setting(:when).to_s.strip.presence || DEFAULT_WHEN

  # «Atención a clientes» con un área en curso: se pasa con canalizar (al equipo de esa área).
  def area_channels?
    areas = @turn.find_skill('areas')
    areas.present? && areas.area_key != 'none'
  end
end
