# frozen_string_literal: true

# «Campaña» — lo de la campaña que manda el código (TrackingCampaigns::CampaignKit dice qué trae cada tipo):
#   - el paquete (WhatsApp): enviar_informacion manda la información completa TAL CUAL (con sus imágenes «con la
#     información») UNA vez; reenviar_informacion solo si la vuelve a pedir;
#   - lo logró, según el objetivo de la campaña:
#       relay / appointment → le_interesa (relevo, Motor2::Relay) o la cita (Motor2::Skills::Appointments)
#       confirm (Invitar)   → confirmar_asistencia (EventAttendee confirmó o canceló)
#       external / done     → ya_lo_hizo: escribió la palabra clave o confirma que YA lo hizo
#       answers (Encuesta)  → guardar_respuesta, una por una y en orden
#   - no esta vez (Invitar, Ofrecer, Reactivar): no_esta_vez → la respuesta fija que pregunta si puede escribirle la
#     próxima; futuras(acepta) con lo que conteste → etiqueta «volver a…» o «no…»;
#   - no_contactar: no quiere que le escriban de esto (baja inmediata, sin pedir motivo);
#     no_le_interesa (Recordar, Encuesta) · mas_adelante: un solo toque más en esa fecha;
#   - las respuestas fijas salen TAL CUAL (la de la campaña o la de fábrica); las etiquetas del contacto las pone
#     Motor2::Functions::CampaignSellerOutcomes después de mandar.
# En el chat de prueba no se toca nada real (ni eventos, ni casos, ni etiquetas, ni relevo).
#
#   memoria: state['content_sent'], state['asked_future'], state['survey'] { '1' => { 'respuesta', 'calificacion' } },
#            state['relay'] (a quién se pasó)
class Motor2::Skills::Campaign < Motor2::Skills::Base
  include Motor2::Skills::CampaignAnswers
  include Motor2::Skills::CampaignNotes

  def self.key = 'campaign'

  def on? = config.skill_on?(key) && function.respond_to?(:purpose)

  def tools
    return [*survey_tools, stop_tool] if function.survey?

    [*info_tools, *link_tools, *goal_tools, *negative_tools, stop_tool, *(function.invite? ? [] : [later])].compact
  end

  RULES = <<~TEXT.strip
    REGLAS DE LA CAMPAÑA:
    - Contesta primero lo que preguntó. Si en un mensaje pide dos cosas, atiende las dos.
    - Una duda concreta (fecha, hora, precio, costo, para quién es) se contesta con LA FICHA, sin mandar la información completa.
    - La información completa se manda una sola vez; si ya se mandó, no la repitas salvo que la pida otra vez. Si solo pide la liga, manda solo esa liga.
    - Lo que no es de esta campaña (otros productos o servicios, cómo funciona la empresa): contesta SOLO con tus fuentes; si no hay, dilo en corto. No lo mezcles con la ficha ni aproveches para invitarlo u ofrecerle la campaña.
    - Si solo saluda o agradece («gracias», «ok», «👍»): contesta corto («¡Con gusto! 😊»), sin preguntas, ligas ni información. «Gracias, pero no» NO es cortesía: es una negativa.
    - Si pide una liga o tiene un problema para entrar, mándale la liga que corresponda de LIGAS en ese mismo mensaje (no le preguntes si la quiere).
    - «Para quién es / no es» sirve para contestar si él pregunta; NO le preguntes si cumple (p. ej. «¿eres distribuidor?») ni le pidas que lo confirme.
    - Si no hace falta preguntar nada, no preguntes: está bien terminar sin pregunta.
    - Nunca pidas nombre, teléfono, correo ni comprobantes, ni digas que revisaste algo que no puedes ver.
    - Si pide que no le escriban, eso gana sobre todo lo demás: no sigas con la campaña.
    - No insistas ni vuelvas a ofrecer por tu cuenta, ni ofrezcas recordatorios o seguimientos: eso lo hace la campaña.
  TEXT

  def instructions
    [RULES, email? ? '- Es por CORREO: saludo y despedida breves; puedes ser un poco más completo; sin emojis de más.' : nil].compact.join("\n")
  end

  def memory
    return '' unless function.survey?

    done = survey.keys.map(&:to_i)
    "ENCUESTA: #{function.survey_questions.size} preguntas; ya contestó: #{done.empty? ? 'ninguna' : done.sort.join(', ')}."
  end

  def turn_note
    return attempt_note if @turn.attempt?
    return message_note if message_note
    return [info_note, future_note].compact_blank.join(' ') unless function.survey?

    number, question = next_question
    return 'Ya contestó toda la encuesta: agradécele en una frase.' unless number

    "Si su mensaje contesta la pregunta pendiente, guárdala con guardar_respuesta. Después haz la #{number} " \
      "tal cual, sola: «#{question}»"
  end

  # La liga que mandó con mandar_liga va sí o sí, exacta (si la IA la cambió o no la puso, se agrega al final).
  def polish(reply)
    return reply if @link_url.blank? || reply.blank? || reply.include?(@link_url)

    "#{reply.rstrip}\n\n#{@link_url}"
  end

  def required_question
    return nil unless function.survey?

    # La parte que pregunta («Del 0 al 10, ¿qué tanto…?» → «¿qué tanto…?»): así la revisa Motor2::QuestionGuard.
    question = next_question&.last
    question && (question[/¿[^¿?]*\?/] || question)
  end

  CALLS = {
    'enviar_informacion' => ->(_a) { send_info! }, 'reenviar_informacion' => ->(_a) { send_info! },
    'le_interesa' => ->(a) { interested(a['resumen']) }, 'ya_lo_hizo' => ->(a) { achieved!(a['nota']) },
    'confirmar_asistencia' => ->(a) { attendance(a['asistira'], a['nota']) }, 'no_esta_vez' => ->(a) { not_now!(a['motivo']) },
    'futuras' => ->(a) { future!(a['acepta'], a['motivo']) }, 'mandar_liga' => ->(a) { send_link(a['liga']) },
    'no_contactar' => ->(a) { opt_out!(a['motivo']) },
    'no_le_interesa' => ->(a) { not_interested!(a['motivo']) }, 'mas_adelante' => ->(a) { later!(a['dias'], a['motivo']) }
  }.freeze

  def call(name, args)
    handler = CALLS[name]
    handler ? instance_exec(args, &handler) : save_answer(args)
  end

  private

  def function = config.function

  def email? = (@turn.tracking&.inbox || @turn.conversation.try(:inbox)).try(:email?) || false

  def contact = @turn.conversation.try(:contact)

  MAX_LATER_DAYS = 120

  # ---------- el paquete ----------

  def content? = function.respond_to?(:content) && function.content.present?

  def info_tools
    return [] unless content?
    return [] if !state['content_sent'] && concrete_question?
    if state['content_sent']
      return [fn('reenviar_informacion', 'Pide EXPRESAMENTE que le vuelvas a mandar la información completa (el flyer, la promoción).')]
    end

    [fn('enviar_informacion', 'SOLO si contesta que sí, que le interesa o pide la información completa: se le manda la ' \
                              'información de la campaña tal cual, con sus imágenes. NO la uses si pregunta un dato (fecha, hora, ' \
                              'costo, para quién) ni si pregunta algo que no es de la campaña: eso se contesta con LA FICHA o tus fuentes.')]
  end

  def info_note
    return '' unless content?

    if state['content_sent']
      return 'Ya le mandaste la información completa: no la repitas; contesta sus dudas con LA FICHA. Si pide la liga, mándale ' \
             'la que corresponda de LIGAS, exacta.'
    end

    'Si contesta que sí o pide la información completa, usa enviar_informacion (no la escribas tú). Una duda concreta se contesta sin ella.'
  end

  # El texto sale aparte, tal cual, después de este turno (sin mensaje de la IA); las imágenes «con la información»
  # van en este turno (primero la imagen, luego el texto). En la prueba no se manda nada: se enseña en el chat.
  def send_info!
    state['content_sent'] = true
    @info_now = true # en este turno solo va la información (el relevo, cuando ya la tiene)
    trace.event(:informacion, 'La información completa de la campaña')
    attach_rule('interest')
    return { ok: true, nota: "Es una prueba: escribe TAL CUAL este texto, sin cambiarlo:\n#{info_text}" } if test?

    text = info_text
    tracking = @turn.tracking
    conversation = @turn.conversation
    @turn.after_send { Motor2::Delivery.send_reply(tracking, conversation, text) }
    @turn.silence!
    { ok: true, nota: 'Listo: se le manda la información tal cual. Escribe solo [SIN_MENSAJE].' }
  end

  def info_text = Motor2::CampaignTouch.fill(function.content, contact, @turn.tracking&.tracking_campaign)

  # ---------- lo logró ----------

  def goal_tools
    case function.goal
    when 'confirm'
      [fn('confirmar_asistencia', 'Dijo claramente si va o no va al evento («me interesa» no es «sí voy»).',
          { asistira: { type: 'boolean' }, nota: STR }, %w[asistira])]
    when 'external', 'done' then will_do? ? [] : [achieved_tool]
    else interest_tools
    end
  end

  # Con información completa, primero va ella: «le interesa» (el relevo) hasta que ya la tiene.
  def interest_tools
    return [] if (content? && !state['content_sent']) || @info_now

    [fn('le_interesa', "Ya lo quiere: pásalo a quien sigue (#{relay_label}). Una pregunta (precio, condiciones) NO es " \
                       "«lo quiere». #{interest_when}", { resumen: STR }, %w[resumen])]
  end

  def achieved_tool
    word = function.goal == 'external' ? "escribió «#{function.keyword}» o " : ''
    fn('ya_lo_hizo', "#{word.capitalize}confirma sin duda que YA lo hizo (no «me interesa», «ahorita lo hago» ni una pregunta). " \
                     'Después escribe la respuesta que te da la herramienta.', { nota: STR })
  end

  def interest_when
    base = if content?
             'Llámala cuando YA lo quiere (comprar, apartar, que lo contacten para cerrar); si solo pide información, usa enviar_informacion.'
           else
             'Llámala cuando muestre interés de verdad (quiere comprar, apartar o que lo contacten); si solo pregunta un dato ' \
               '(precio, vigencia, condiciones), contéstalo con LA FICHA y pregúntale si le interesa.'
           end
    quote_first? ? "#{base} Si pide una COTIZACIÓN, primero llama cotizar y después esta herramienta." : base
  end

  # Ofrecer con cotización: la cotización va antes del relevo.
  def quote_first? = function.respond_to?(:quote_mode) && function.quote_mode.to_s != 'off' && !function.survey?

  def achieved!(note)
    @turn.decide('achieved', note.presence || 'Lo hizo')
    trace.event(:campana, 'Lo logró')
    attach_rule('confirm')
    fixed('achieved')
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

  def attendance(going, note)
    status = going == true ? :confirmed : :cancelled
    error = test? ? nil : mark_attendee(status)
    return { error: error } if error

    trace.event(:evento, status == :confirmed ? 'Confirmó su asistencia' : 'No va')
    return not_now!(note.presence || 'No va') unless status == :confirmed

    @turn.decide('achieved', ['Confirmó su asistencia', note.presence].compact.join(': '))
    attach_rule('confirm') # mapa, agenda, boleto…
    fixed('achieved')
  end

  # Su lugar en el evento (Eventos): confirmó o canceló. Regresa el error, o nil.
  def mark_attendee(status)
    event = function.event
    return 'La campaña no tiene evento: pásalo con una persona.' unless event && contact

    attendee = event.attendees.find_or_initialize_by(contact: contact) { |a| a.account_id = event.account_id }
    attendee.source = 'agent' if attendee.new_record?
    attendee.update!(status: status)
    nil
  end

  # Los archivos del agente con esa regla van con el mensaje de este turno.
  def attach_rule(rule)
    names = Motor2::Skills::Files.with_rule(config, rule, config.attachments)
    names.first(Motor2::Skills::Files::MAX_PER_MESSAGE).each { |name| @turn.attach(name) }
  end
end
