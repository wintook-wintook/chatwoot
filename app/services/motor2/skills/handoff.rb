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
    [fn('pasar_a_humano', "Pásalo a una persona del equipo cuando: #{when_text}. Después escribe solo la despedida.",
        { motivo: STR }, %w[motivo])]
  end

  def instructions = "- Pasa a una persona (pasar_a_humano) cuando: #{when_text}."

  def call(_name, args)
    @turn.decide('handoff', args['motivo'])
    { ok: true, nota: 'Listo. Ahora escribe solo la despedida para el cliente: dile que una persona le sigue.' }
  end

  private

  def when_text = setting(:when).to_s.strip.presence || DEFAULT_WHEN
end
