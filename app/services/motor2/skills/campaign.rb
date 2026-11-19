# frozen_string_literal: true

# «Campaña» — lo del Vendedor de campaña que manda el código (Plan-Motor-Agentes §11.16):
#   - Ofrecer / Reactivar / Renovar: le_interesa → relevo (Motor2::Relay) a quien sigue;
#     no_le_interesa → se despide y el seguimiento se cierra;
#   - Invitar: confirmar_asistencia → su lugar en el evento (EventAttendee confirmó o canceló);
#   - Encuesta: las preguntas tal cual y en orden, una por mensaje (el código lleva cuál sigue);
#     guardar_respuesta; al terminar, si una calificación es baja, se levanta un caso.
# En el chat de prueba no se toca nada real (ni eventos, ni casos, ni relevo).
#
#   memoria: state['survey'] { '1' => { 'respuesta', 'calificacion' } }, state['relay'] (a quién se pasó)
class Motor2::Skills::Campaign < Motor2::Skills::Base
  def self.key = 'campaign'

  def on? = config.skill_on?(key) && function.respond_to?(:purpose)

  def tools
    return survey_tools if function.survey?
    return invite_tools if function.invite?

    [fn('le_interesa', "Le interesa la oferta: pásalo a quien sigue (#{relay_label}). Llámala en cuanto muestre interés " \
                       '(pide precio, detalles, quiere comprar o que lo contacten).', { resumen: STR }, %w[resumen]),
     not_interested]
  end

  def memory
    return '' unless function.survey?

    done = survey.keys.map(&:to_i)
    "ENCUESTA: #{function.survey_questions.size} preguntas; ya contestó: #{done.empty? ? 'ninguna' : done.sort.join(', ')}."
  end

  def turn_note
    return '' unless function.survey?

    number, question = next_question
    return 'Ya contestó toda la encuesta: agradécele en una frase.' unless number

    "Si su mensaje contesta la pregunta pendiente, guárdala con guardar_respuesta. Después haz la #{number} " \
      "tal cual, sola: «#{question}»"
  end

  def required_question
    return nil unless function.survey?

    # La parte que pregunta («Del 0 al 10, ¿qué tanto…?» → «¿qué tanto…?»): así la revisa Motor2::QuestionGuard.
    question = next_question&.last
    question && (question[/¿[^¿?]*\?/] || question)
  end

  def call(name, args)
    case name
    when 'le_interesa' then interested(args['resumen'])
    when 'no_le_interesa' then not_interested!(args['motivo'])
    when 'confirmar_asistencia' then attendance(args['asistira'], args['nota'])
    else save_answer(args)
    end
  end

  private

  def function = config.function

  CONFIRMED = 'Quedó confirmado: agradécele y recuérdale fecha, hora y lugar (o liga) en una o dos frases, sin preguntas.'

  def not_interested
    fn('no_le_interesa', 'Dijo claramente que no le interesa. Después escribe solo una despedida corta y amable.',
       { motivo: STR }, %w[motivo])
  end

  def invite_tools
    [fn('confirmar_asistencia', 'Dijo si va o no va al evento: lo deja confirmado o cancelado.',
        { asistira: { type: 'boolean' }, nota: STR }, %w[asistira]),
     not_interested]
  end

  def survey_tools
    [fn('guardar_respuesta', 'Guarda lo que contestó a la pregunta pendiente de la encuesta.',
        { respuesta: STR, calificacion: { type: 'integer', description: 'Si la pregunta es de 0 a 10 (o 1 a 5), el número que dio' } },
        %w[respuesta])]
  end

  def relay_label = function.relay_to_person? ? 'tu equipo' : 'el agente que sigue o tu equipo'

  # Le interesa: el relevo se hace después de mandar (Motor2::Relay); quien sigue le contesta.
  def interested(summary)
    target = test? ? nil : Motor2::Relay.target_for(@turn.tracking, function)
    @turn.decide('relay', summary.to_s)
    state['relay'] = target ? target[:name] : 'equipo'
    silent = silent_relay?(target)
    # Las imágenes de «cuando muestre interés»: con el relevo a un agente las manda Motor2::Relay (este
    # turno no lleva mensaje); a una persona, van con este mensaje. En la prueba se ven en el chat.
    attach_rule('interest') if !silent || test?
    if silent
      @turn.silence! # quien sigue contesta este mismo mensaje (Motor2::Relay)
      return { ok: true, nota: 'Listo: quien sigue le contesta ahora mismo. Escribe solo [SIN_MENSAJE].' }
    end

    { ok: true, nota: 'Listo: alguien del equipo le escribe. Dile en una frase que con gusto, que en un momento lo contactan; ' \
                      'sin preguntas ni ofrecer nada más.' }
  end

  # Con el relevo a un agente, este turno no lleva mensaje (contesta quien sigue).
  def silent_relay?(target) = target&.dig(:agent).present? || (test? && !function.relay_to_person?)

  def not_interested!(reason)
    @turn.decide('discarded', reason.to_s)
    { ok: true, nota: 'Listo. Despídete en una frase, sin insistir.' }
  end

  def attendance(going, note)
    status = going == true ? :confirmed : :cancelled
    error = test? ? nil : mark_attendee(status)
    return { error: error } if error

    text = status == :confirmed ? 'Confirmó su asistencia' : ['No va', note.presence].compact.join(': ')
    trace.event(:evento, text)
    attach_rule('confirm') if status == :confirmed # mapa, agenda, boleto…
    @turn.decide('done', text)
    { ok: true, nota: status == :confirmed ? CONFIRMED : 'Quedó como que no va: agradécele en una frase, sin preguntas.' }
  end

  # Su lugar en el evento (Eventos): confirmó o canceló. Regresa el error, o nil.
  def mark_attendee(status)
    event = function.event
    return 'El agente no tiene evento: pásalo con una persona.' unless event && contact

    attendee = event.attendees.find_or_initialize_by(contact: contact) { |a| a.account_id = event.account_id }
    attendee.source = 'agent' if attendee.new_record?
    attendee.update!(status: status)
    nil
  end

  def save_answer(args)
    number, question = next_question # el código sabe cuál toca (el modelo se equivoca de número)
    return { error: 'Ya contestó todas: agradécele.' } unless question
    return { error: NOT_AN_ANSWER } unless answers?(question)

    survey[number.to_s] = { 'respuesta' => args['respuesta'].to_s.first(500), 'calificacion' => args['calificacion'] }.compact
    state['survey'] = survey
    trace.event(:encuesta, "#{number}: #{args['respuesta']}")
    return { ok: true } if next_question

    @turn.decide('done', 'Contestó la encuesta')
    { ok: true, nota: 'Ya contestó toda la encuesta: agradécele en una frase (sin más preguntas).' }
  end

  NOT_AN_ANSWER = 'Eso no contesta la pregunta (dijo que sí a la encuesta, saludó o preguntó otra cosa): no la guardes; ' \
                  'haz la pregunta pendiente tal cual.'

  # ¿Lo que dijo contesta la pregunta? («va», «sí, claro» no contestan «del 0 al 10…»).
  def answers?(question)
    Motor2::AnswerCheck.new(account: config.account).answers?(question: question, message: @turn.last_customer)
  end

  def survey = (state['survey'] ||= {})

  def next_question
    function.survey_questions.each_with_index do |question, i|
      return [i + 1, question] unless survey.key?((i + 1).to_s)
    end
    nil
  end

  def contact = @turn.conversation&.contact

  # Los archivos del agente con esa regla van con el mensaje de este turno.
  def attach_rule(rule)
    names = Motor2::Skills::Files.with_rule(config.template, rule, config.attachments)
    names.first(Motor2::Skills::Files::MAX_PER_MESSAGE).each { |name| @turn.attach(name) }
  end
end
