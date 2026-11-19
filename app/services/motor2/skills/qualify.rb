# frozen_string_literal: true

# «Calificar» — el agente junta las respuestas del prospecto a las preguntas de la empresa y dice
# cuándo ya califica, con su temperatura (caliente, tibio, frío). Lo que pasa después lo decide la
# función (Motor2::Functions::ProspectOutcomes: etiqueta «interesado», nota, pasarlo, crear la
# oportunidad). Viene del agente listo de antes (ReadyAgents::Runner#save_answer / #decide).
#
#   skills.qualify = { 'on' => true }   (lo prende la función «Atención a prospectos»)
#   memoria: state['answers'] = { 'Presupuesto' => '20 mil' }, state['temperature'] = 'caliente'
class Motor2::Skills::Qualify < Motor2::Skills::Base
  TEMPERATURES = %w[caliente tibio frio].freeze
  TEMPERATURE = { type: 'string', enum: TEMPERATURES, description: 'Qué tan listo está para comprar' }.freeze

  def self.key = 'qualify'

  def on? = config.skill_on?(key)

  def tools
    [fn('guardar_respuesta', 'Guarda lo que el prospecto contestó a una de las preguntas para calificarlo.',
        { pregunta: STR, respuesta: STR }, %w[pregunta respuesta]),
     fn('prospecto_calificado', 'El prospecto cumple lo de «calificado»: se pasa al siguiente paso. Después escribe solo ' \
                                'la despedida con el siguiente paso.', { resumen: STR, temperatura: TEMPERATURE },
        %w[resumen temperatura])]
  end

  def memory
    saved = answers
    saved.any? ? "LO QUE YA CONTESTÓ: #{saved.map { |q, a| "#{q}: #{a}" }.join(' | ')}" : ''
  end

  def call(name, args)
    name == 'guardar_respuesta' ? save(args) : qualified(args)
  end

  # La temperatura que dio el modelo al calificar o al pasarlo (también la usa pasar_a_humano).
  def self.note_temperature(state, value)
    state['temperature'] = value.to_s if TEMPERATURES.include?(value.to_s)
  end

  private

  def answers = (state['answers'] ||= {})

  def save(args)
    return { error: 'Falta la pregunta o la respuesta.' } if args['pregunta'].blank? || args['respuesta'].blank?

    answers[args['pregunta'].to_s.first(80)] = args['respuesta'].to_s.first(300)
    trace.event(:respuesta, "#{args['pregunta']}: #{args['respuesta']}")
    { ok: true }
  end

  # Calificarlo pide antes los datos obligatorios del contacto (los que marcó la empresa).
  def qualified(args)
    missing = config.function&.missing_contact(@turn.conversation&.contact, @turn.noted_contact) || []
    return { error: "Antes de calificarlo pídele su #{missing.join(' y ')} (con naturalidad) y guárdalo con actualizar_contacto." } if missing.any?

    self.class.note_temperature(state, args['temperatura'])
    @turn.decide('qualified', args['resumen'])
    { ok: true, nota: 'Listo. Ahora escribe solo el mensaje final para el cliente.' }
  end
end
