# frozen_string_literal: true

# «Calificar» — el agente junta las respuestas del prospecto a las preguntas de la empresa y dice
# cuándo ya califica, con su temperatura (caliente, tibio, frío). Lo que pasa después lo decide la
# función (Motor2::Functions::ProspectOutcomes: etiqueta «interesado», nota, pasarlo, crear la
# oportunidad). Viene del agente listo de antes (ReadyAgents::Runner#save_answer / #decide).
#
#   skills.qualify = { 'on' => true }   (lo prende la función «Atención a prospectos»)
#   memoria: state['answers'] = { '¿Tienes un presupuesto?' => '20 mil' }, state['temperature'] = 'caliente'
#
# Las preguntas vienen numeradas de la función (Motor2::Functions::Prospects#questions) y la
# secuencia la manda el código, no el modelo (gpt-4o-mini se las saltaba y no las guardaba):
#   - prepare: ve qué pregunta hizo el agente en su último mensaje (tal cual);
#   - turn_note: al final del turno le dice «el cliente acaba de contestar la pregunta N: si la
#     contesta, guárdala; si no, vuelve a hacerla» y con qué pregunta debe terminar su mensaje (no se
#     guarda a ciegas: «para viajar» no es la respuesta de «¿Para cuándo?»);
#   - required_question: Motor2::Runner revisa que la traiga (si no, se la pide o la agrega).
# El modelo también puede guardar con guardar_respuesta (si lo dijo de pasada).
# Quién pide una persona y la frase para retomar conectando: Motor2::Skills::QualifyFlow.
class Motor2::Skills::Qualify < Motor2::Skills::Base
  include Motor2::Skills::QualifyFlow

  TEMPERATURES = %w[caliente tibio frio].freeze
  TEMPERATURE = { type: 'string', enum: TEMPERATURES, description: 'Qué tan listo está para comprar' }.freeze

  # Ya contestó todo: no se inventan más preguntas; se decide.
  ALL_ANSWERED = 'YA CONTESTÓ TODAS TUS PREGUNTAS: no inventes otras. Si cumple lo de «calificado», llama ' \
                 'prospecto_calificado; si no, pregúntale solo lo que falte para saberlo, o descártalo si cumple lo de ' \
                 '«se descarta». Si pregunta algo, contéstale.'
  # Con el objetivo «agendarle una cita», al terminar las preguntas toca ofrecer horarios.
  ALL_ANSWERED_APPOINTMENT = 'YA CONTESTÓ TODAS TUS PREGUNTAS: no inventes otras. Si cumple lo de «calificado», ofrécele ' \
                             'YA 2 o 3 horarios de ver_horarios (agendar la cita lo califica); si no cumple, pregúntale solo ' \
                             'lo que falte para saberlo. Si pregunta algo, contéstale.'

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
    if answers.any?
      lines << "LO QUE YA CONTESTÓ: #{answers.map { |q, a| "#{q} → #{a}" }.join(' | ')} (si después da una mejor respuesta a " \
               'una, guárdala otra vez con su número: reemplaza la anterior)'
    end
    numbers = pending_now.pluck(:number)
    if must_handoff?
      lines << handoff_note
    elsif numbers.any?
      lines << "TE FALTA PREGUNTAR (en orden; la siguiente es la #{numbers.first}): #{numbers.join(', ')}. Aunque contestes " \
               "otra cosa, termina tu mensaje con la pregunta #{numbers.first}."
    elsif questions.any?
      lines << all_answered_note
    end
    lines.join("\n")
  end

  def call(name, args)
    name == 'guardar_respuesta' ? save(args) : qualified(args)
  end

  # La pregunta pendiente que hizo el agente en su último mensaje (si el cliente ya contestó después).
  def prepare(history)
    scan_flow(history)
    last = Array(history).rindex { |m| m[:role].to_s == 'assistant' }
    return @just_asked = nil unless last && history[(last + 1)..].any? { |m| m[:role].to_s == 'user' }

    @just_asked = pending.reverse.find { |q| self.class.asks?(history[last][:content], q[:ask]) }
  end

  def turn_note
    return handoff_note if must_handoff?

    notes = []
    if @just_asked && detour?
      notes << "En vez de contestar tu pregunta #{@just_asked[:number]} («#{@just_asked[:ask]}»), el cliente preguntó o pidió " \
               'otra cosa: atiéndelo y vuelve a hacerla. NO guardes lo que preguntó como respuesta.'
    elsif @just_asked
      notes << "Le preguntaste #{@just_asked[:number]}. «#{@just_asked[:ask]}». ¿Su último mensaje contesta EXACTAMENTE eso? Si sí, " \
               "guárdalo YA con guardar_respuesta numero #{@just_asked[:number]}. Si contesta otra cosa (p. ej. le preguntas para " \
               'cuándo y dice para qué), guarda eso en la pregunta que sí contesta y vuelve a hacer esta.'
    end
    ask = required_question
    notes << bridge_note if ask
    notes << "Termina tu mensaje con la pregunta pendiente, tal cual: «#{ask}» (salvo que lo califiques, descartes o pases)." if ask
    notes.compact.join("\n")
  end

  # Sin pregunta si toca pasarlo, o si la bienvenida ya pregunta y el cliente solo saludó.
  def required_question
    return nil if must_handoff? || (@turn.respond_to?(:welcome_asks?) && @turn.welcome_asks?)

    pending_now.first&.dig(:ask)
  end

  # ¿El texto trae la pregunta? Sin acentos, mayúsculas ni signos.
  def self.asks?(text, ask)
    key = normalize(ask)
    key.present? && normalize(text).include?(key)
  end

  def self.normalize(text) = I18n.transliterate(text.to_s.downcase).gsub(/[^a-z0-9 ]/, ' ').squish

  # La temperatura que dio el modelo al calificar o al pasarlo (también la usa pasar_a_humano).
  def self.note_temperature(state, value)
    state['temperature'] = value.to_s if TEMPERATURES.include?(value.to_s)
  end

  private

  def answers = (state['answers'] ||= {})

  def questions = config.function.respond_to?(:questions) ? config.function.questions : []

  def pending = questions.reject { |q| answers.key?(q[:ask]) }

  # Con el número de la pregunta (o, si no hay lista, el texto de la pregunta).
  def save(args)
    question = question_for(args)
    return { error: "No existe la pregunta #{args['numero']}." } if question.nil?
    return { error: 'Falta la respuesta.' } if args['respuesta'].blank?
    return { error: 'Eso lo preguntó el cliente: no es su respuesta. Contéstale y vuelve a hacer la pregunta.' } if its_question?(args)
    return { ok: true, sin_cambio: true } if answers[question] == args['respuesta'].to_s.first(300)
    return not_an_answer(question) unless answer_check.answers?(question: question, message: args['respuesta'])

    answers[question.first(300)] = args['respuesta'].to_s.first(300)
    trace.event(:respuesta, "#{question}: #{args['respuesta']}")
    progress
  end

  # Lo que dijo no contesta esa pregunta (una objeción, otro tema): no se guarda y se vuelve a hacer.
  def not_an_answer(question)
    @rejected = true
    { error: "Eso no contesta «#{question}»: NO lo guardes. Atiende lo que dijo (objeción, duda u otro tema) y vuelve a " \
             'hacer esa pregunta.' }
  end

  def answer_check = @answer_check ||= Motor2::AnswerCheck.new(account: config.account)

  def question_for(args)
    questions.find { |q| q[:number] == args['numero'].to_i }&.dig(:ask) || args['pregunta'].to_s.strip.presence
  end

  # En el mismo turno se entera de cómo va (si no, inventa preguntas o no lo califica).
  def progress
    next_up = pending_now.first
    next_up ? { ok: true, siguiente: "#{next_up[:number]}. #{next_up[:ask]}" } : { ok: true, nota: all_answered_note }
  end

  def all_answered_note
    config.function.respond_to?(:appointment?) && config.function.appointment? ? ALL_ANSWERED_APPOINTMENT : ALL_ANSWERED
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
