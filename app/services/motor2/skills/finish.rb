# frozen_string_literal: true

# Terminar — el objetivo se cumplió, o no es para nosotros. Siempre prendida.
class Motor2::Skills::Finish < Motor2::Skills::Base
  def self.key = 'finish'

  def on? = true

  # Con «Calificar» prendida, el objetivo se cumple con prospecto_calificado (no hay objetivo_cumplido).
  def tools
    done = fn('objetivo_cumplido', 'Ya se logró el objetivo del agente. Después escribe solo el mensaje final.',
              { resumen: STR }, %w[resumen])
    discard = fn('descartar', 'No le interesa o no es para nosotros. Después escribe solo la despedida.',
                 { motivo: STR }, %w[motivo])
    config.skill_on?(:qualify) ? [discard] : [done, discard]
  end

  def call(name, args)
    name == 'objetivo_cumplido' ? @turn.decide('done', args['resumen']) : @turn.decide('discarded', args['motivo'])
    { ok: true, nota: 'Listo. Ahora escribe solo el mensaje final para el cliente (o [SIN_MENSAJE]).' }
  end
end
