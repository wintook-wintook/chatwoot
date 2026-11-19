# frozen_string_literal: true

# «Calificar» — el agente junta las respuestas del prospecto a las preguntas de la empresa y dice
# cuándo ya califica, con su temperatura (caliente, tibio, frío). Lo que pasa después lo decide la
# función (Motor2::Functions::ProspectOutcomes: etiqueta «interesado», nota, pasarlo, crear la
# oportunidad). Viene del agente listo de antes (ReadyAgents::Runner#save_answer / #decide).
#
#   skills.qualify = { 'on' => true }   (lo prende la función «Atención a prospectos»)
#   memoria: state['answers'] = { '¿Tienes un presupuesto?' => '20 mil' }, state['temperature'] = 'caliente'
#
# Las preguntas vienen numeradas de la función (Motor2::Functions::Prospects#questions): el modelo
# guarda con el número y el código lleva la cuenta (cuáles ya contestó y cuál sigue), como en
# «Datos del cliente». Así no se salta ni repite y cada respuesta queda en la nota.
class Motor2::Skills::Qualify < Motor2::Skills::Base
  TEMPERATURES = %w[caliente tibio frio].freeze
  TEMPERATURE = { type: 'string', enum: TEMPERATURES, description: 'Qué tan listo está para comprar' }.freeze

  def self.key = 'qualify'

  def on? = config.skill_on?(key)

  def tools
    [fn('guardar_respuesta', 'Guarda lo que el prospecto contestó a una de las preguntas para calificarlo (en cuanto lo diga, ' \
                             'aunque no se lo hayas preguntado).',
        { numero: { type: 'integer', description: 'El número de la pregunta' }, respuesta: STR }, %w[numero respuesta]),
     fn('prospecto_calificado', 'El prospecto cumple lo de «calificado»: se pasa al siguiente paso. Después escribe solo ' \
                                'la despedida con el siguiente paso.', { resumen: STR, temperatura: TEMPERATURE },
        %w[resumen temperatura])]
  end

  def memory
    lines = []
    lines << "LO QUE YA CONTESTÓ: #{answers.map { |q, a| "#{q} → #{a}" }.join(' | ')}" if answers.any?
    pending = questions.reject { |q| answers.key?(q[:ask]) }.pluck(:number)
    if pending.any?
      lines << "TE FALTA PREGUNTAR (en orden; la siguiente es la #{pending.first}): #{pending.join(', ')}. Aunque contestes " \
               "otra cosa, termina tu mensaje con la pregunta #{pending.first} (si no la acaba de contestar)."
    end
    lines.join("\n")
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

  def questions = config.function.respond_to?(:questions) ? config.function.questions : []

  # Con el número de la pregunta (o, si no hay lista, el texto de la pregunta).
  def save(args)
    question = questions.find { |q| q[:number] == args['numero'].to_i }&.dig(:ask) || args['pregunta'].to_s.strip.presence
    return { error: "No existe la pregunta #{args['numero']}." } if question.nil?
    return { error: 'Falta la respuesta.' } if args['respuesta'].blank?

    answers[question.first(300)] = args['respuesta'].to_s.first(300)
    trace.event(:respuesta, "#{question}: #{args['respuesta']}")
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
