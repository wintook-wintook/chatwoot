# frozen_string_literal: true

# «Campaña» (Motor2::Skills::Campaign) — las respuestas fijas, «no esta vez» con la pregunta por la próxima, «no me
# escriban», «más adelante» y lo que escribe la IA en los toques (el primer mensaje corto en WhatsApp; en correo,
# el primero con todo y los siguientes según si dio clic).
module Motor2::Skills::CampaignAnswers
  STR = Motor2::Tools::STR

  private

  # La respuesta fija tal cual; en una línea corta antes, lo que haya preguntado además.
  def fixed(key)
    text = Motor2::CampaignTouch.fill_contact(function.reply_text(key), contact).strip
    return { ok: true, nota: 'Listo. Contesta en una frase, sin preguntas.' } if text.blank?

    { ok: true, nota: 'Listo. Escribe TAL CUAL esta respuesta y NADA MÁS después (ni preguntas, ni ofrecer información); si ' \
                      "además preguntó algo, contéstalo ANTES en una frase:\n#{text}" }
  end

  # ---------- no esta vez / la próxima / no contactar ----------

  def negative_tools
    return [not_interested] unless function.asks_future?
    return [future_tool] if state['asked_future']

    [fn('no_esta_vez', 'No puede o no le interesa ESTA vez («no tengo tiempo», «tengo otro compromiso», «por ahora paso», ' \
                       '«no me interesa» sin decir que no le escriban): se le pregunta si puede escribirle la próxima. ' \
                       'Después escribe la respuesta que te da la herramienta.', { motivo: STR }, %w[motivo])]
  end

  def future_tool
    fn('futuras', 'Contestó si quiere que le escribamos la próxima vez (la pregunta que se le hizo).',
       { acepta: { type: 'boolean' }, motivo: STR }, %w[acepta])
  end

  def future_note
    return nil unless function.asks_future? && state['asked_future']

    'Ya le preguntaste si le escribimos la próxima vez: si contesta eso, usa futuras.'
  end

  def not_now!(reason)
    return opt_out!(reason) if state['asked_future'] # ya se le preguntó: un segundo «no» es que no

    state['asked_future'] = true
    @turn.decide('not_now', reason.to_s)
    fixed('not_now')
  end

  def future!(accepts, reason)
    return opt_out!(reason) unless accepts == true

    @turn.decide('future_yes', reason.to_s)
    fixed('future_yes')
  end

  def stop_tool
    fn('no_contactar', 'Pide que no le escriban o no lo vuelvan a invitar («no me manden nada», «no me inviten», «bórrenme»): ' \
                       'se respeta ya, sin preguntar el motivo. Después escribe la respuesta que te da la herramienta.',
       { motivo: STR })
  end

  def opt_out!(reason)
    @turn.decide('opt_out', reason.to_s)
    fixed('opt_out')
  end

  def not_interested
    fn('no_le_interesa', 'Dijo claramente que no le interesa. Después escribe solo una despedida corta y amable.',
       { motivo: STR }, %w[motivo])
  end

  def not_interested!(reason)
    @turn.decide('discarded', reason.to_s)
    { ok: true, nota: 'Listo. Despídete en una frase, sin insistir.' }
  end

  def later
    fn('mas_adelante', 'Dice que AHORA NO pero da una fecha o pide tiempo («escríbeme en marzo», «dame hasta el viernes», ' \
                       '«estoy de vacaciones», respuesta automática de fuera de la oficina): se le vuelve a escribir una vez ' \
                       'en esa fecha. Después despídete en una frase diciendo que le escribes entonces.',
       { dias: { type: 'integer', description: 'En cuántos días volver a escribirle (si no dijo, 30)' }, motivo: STR }, %w[dias])
  end

  def later!(days, reason)
    days = (days.presence || 30).to_i.clamp(1, Motor2::Skills::Campaign::MAX_LATER_DAYS)
    @turn.decide('later', "#{days}|#{reason}")
    { ok: true, nota: "Listo: se le vuelve a escribir en #{days} días. Despídete en una frase, sin preguntas." }
  end

  # ---------- encuesta ----------

  def survey_tools
    [fn('guardar_respuesta', 'Guarda lo que contestó a la pregunta pendiente de la encuesta.',
        { respuesta: STR, calificacion: { type: 'integer', description: 'Si la pregunta es de 0 a 10 (o 1 a 5), el número que dio' } },
        %w[respuesta])]
  end

  def save_answer(args)
    number, question = next_question # el código sabe cuál toca (el modelo se equivoca de número)
    return { error: 'Ya contestó todas: agradécele.' } unless question
    return { error: NOT_AN_ANSWER } unless answers?(question)

    survey[number.to_s] = { 'respuesta' => args['respuesta'].to_s.first(500), 'calificacion' => args['calificacion'] }.compact
    state['survey'] = survey
    trace.event(:encuesta, "#{number}: #{args['respuesta']}")
    after_answer
  end

  # La que sigue, tal cual (si no, la IA arrastra el rango de la anterior); al terminar, gracias o «lamentamos…» si fue baja.
  def after_answer
    upcoming = next_question
    return { ok: true, nota: "Guardada. Ahora haz SOLO la pregunta #{upcoming[0]}, tal cual: «#{upcoming[1]}»" } if upcoming

    @turn.decide('done', 'Contestó la encuesta')
    fixed(survey.any? { |n, v| function.low_answer?(n, v['calificacion']) } ? 'low' : 'achieved')
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
end
