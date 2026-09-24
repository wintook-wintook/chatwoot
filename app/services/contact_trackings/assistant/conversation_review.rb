# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — REVISAR UNA CONVERSACIÓN REAL
# ================================================================================
# Qué respuestas del agente estuvieron mal en una conversación real, por qué, y qué
# cambiar (pedido del usuario, 24/09/2026: «puntualizar las peticiones y respuestas
# inexactas o que no son lo que esperaba»).
#
#   1. EVIDENCIA (sin IA, ConversationEvidence): mensajes, seguimiento, Agente IA y
#      el Entrenamiento que corrió.
#   2. EL MOTOR, HOY (DryRunService por cada mensaje del cliente): a qué ruta cae,
#      qué fuente consulta, qué etiqueta pone. Es el motor real con la configuración
#      de hoy; no es un registro de lo que pasó ese día (eso no se guarda).
#   3. HECHOS DE CONFIGURACIÓN (sin IA): agenda sin calendario, copia vieja del
#      Entrenamiento, hallazgos bloqueantes del comprobador.
#   4. EL VEREDICTO (gpt-4o): cada respuesta contra el Entrenamiento y los hechos.
#      Separa la CAUSA: entrenamiento / configuración / motor. Es lo que evita
#      «arreglar» el prompt por algo que no es del prompt (la 173: faltaba el
#      calendario, y el Entrenamiento estaba bien).
#
# NO CAMBIA NADA. La corrección la aplica el chat del Asistente en el turno
# siguiente, si la persona la pide, sobre el Entrenamiento abierto.
# ================================================================================

class ContactTrackings::Assistant::ConversationReview
  MODEL = 'gpt-4o'
  MAX_OUTPUT_TOKENS = 3000
  # Cada mensaje del cliente es una clasificación (y un embedding si su ruta busca).
  # Más que esto encarece y alarga sin cambiar el diagnóstico: se toman los últimos.
  MAX_REPLAYS = 12
  VERDICTS = %w[mal dudoso].freeze
  CAUSES = %w[entrenamiento configuracion motor cliente].freeze

  def initialize(account, display_id:, note: nil, draft: nil, inbox: nil, progress: nil) # rubocop:disable Metrics/ParameterLists
    @account = account
    @evidence = ContactTrackings::Assistant::ConversationEvidence.new(account, display_id)
    @note = note.to_s.strip.truncate(1000)
    @draft = draft.to_s
    @inbox = inbox
    @progress = progress || ->(*, **) {}
    @chat = ContactTrackings::Assistant::OpenaiChat.new(account: account, inbox: inbox)
  end

  def call
    return { error: 'not_found' } unless @evidence.found?
    return { error: 'no_messages' } if @evidence.turns.empty?
    return { error: 'no_api_key' } if @chat.api_key.blank?

    @progress.call(:review_loading)
    @engine = replays
    @progress.call(:review_analyzing)
    verdict = analyze(@engine)
    return { error: 'unavailable' } if verdict.nil?

    payload(verdict)
  end

  private

  def payload(verdict)
    {
      conversation: conversation_json,
      agent: agent_json,
      facts: facts,
      summary: verdict['resumen'].to_s.strip.truncate(800),
      ok: judged(verdict).select { |f| f['veredicto'] == 'bien' }.map { |f| f['n'].to_i } - signals.keys,
      findings: findings(verdict),
      training_changes: Array(verdict['cambios_entrenamiento']).map { |c| c.to_s.strip.truncate(400) }.compact_blank.first(8)
    }
  end

  # ── la evidencia, para la pantalla ─────────────────────────────────────────
  def conversation_json
    c = @evidence.conversation
    { display_id: c.display_id, inbox: c.inbox&.name, messages: @evidence.total_messages,
      reviewed: @evidence.turns.size, truncated: @evidence.truncated? }
  end

  def agent_json
    t = @evidence.template
    return nil if @evidence.tracking.nil?

    { tracking_id: @evidence.tracking.id, template_id: t&.id, name: t&.name, stale_copy: @evidence.stale_copy? }
  end

  def bot_numbers
    @bot_numbers ||= @evidence.turns.select { |t| t.role == 'bot' }.map(&:n)
  end

  def turn(numero)
    @evidence.turns.find { |t| t.n == numero }
  end

  # ── 2. el motor, hoy ───────────────────────────────────────────────────────
  def replays
    return {} if prompt.blank?

    clientes = @evidence.turns.select { |t| t.role == 'cliente' }.last(MAX_REPLAYS)
    clientes.each_with_index.to_h do |t, i|
      @progress.call(:review_replaying, round: i + 1, of: clientes.size)
      [t.n, replay(t)]
    end
  end

  def replay(turno)
    result = ContactTrackings::Assistant::DryRunService
             .new(@account, draft: prompt, question: turno.content, inbox: @evidence.conversation.inbox,
                            recent_context: recent_context(turno)).call
    result.success? ? result.payload : nil
  rescue StandardError => e
    Rails.logger.warn "[Asistente/Revisión] no se pudo re-correr el mensaje #{turno.n}: #{e.message}"
    nil
  end

  # Los 4 mensajes anteriores, como los arma el motor (get_recent_context del
  # ContactTrackingResponseAnalyzerJob): el clasificador decide con ellos.
  RECENT_CONTEXT = 4
  CONTEXT_ROLES = %w[cliente bot humano].freeze

  def recent_context(turno)
    @evidence.turns.select { |t| t.n < turno.n && CONTEXT_ROLES.include?(t.role) }.last(RECENT_CONTEXT)
             .map { |t| "#{t.role == 'cliente' ? 'Cliente' : 'Bot'}: #{t.content.truncate(120)}" }.join("\n")
  end

  # El que corrió es el que se juzga. Sin seguimiento (una conversación que no
  # atendió ningún agente), el Entrenamiento abierto en el Asistente.
  def prompt
    @prompt ||= @evidence.ran_prompt.presence || @draft
  end

  # ── 3. hechos de configuración ─────────────────────────────────────────────
  def facts
    @facts ||= [no_agent, calendar, stale_copy, *blocking].compact
  end

  def no_agent
    return nil if @evidence.tracking

    { code: 'no_agent' }
  end

  # Si hoy SÍ tiene, también se dice: no se guarda desde cuándo, y una conversación
  # vieja pudo fallar por no tenerlo (la 173). Ya estaría corregido.
  def calendar
    return nil unless prompt.match?(/@agendar_calendar\b/i) && @evidence.tracking

    { code: @evidence.calendar_configured? ? 'calendar_ok' : 'no_calendar' }
  end

  def stale_copy
    @evidence.stale_copy? ? { code: 'stale_copy', name: @evidence.template.name } : nil
  end

  def blocking
    return [] if prompt.blank?

    bloqueantes = ContactTrackings::Assistant::ValidatorService.new(prompt, account: @account).call[:blocking]
    bloqueantes.first(5).map { |f| { code: 'blocking', message: f[:message].to_s.truncate(300) } }
  end

  # ── 4. el veredicto ────────────────────────────────────────────────────────
  def analyze(engine)
    texto = ContactTrackings::Assistant::ConversationReviewPrompt.new(
      ran: prompt, current: current_prompt, facts: facts, note: @note,
      transcript: ContactTrackings::Assistant::ConversationReviewPrompt.transcript(@evidence.turns, engine, signals)
    ).call
    reply = @chat.call([{ role: 'system', content: texto }], max_tokens: MAX_OUTPUT_TOKENS, model: MODEL)
    reply.is_a?(Hash) ? reply : nil
  end

  # Una por respuesta del bot: lo que juzgó el modelo más lo comprobado sin IA
  # (`signals`). Una respuesta con señales está mal aunque el modelo la diera por buena.
  def findings(verdict)
    del_modelo = judged(verdict).reject { |f| f['veredicto'] == 'bien' }.index_by { |f| f['n'].to_i }
    (del_modelo.keys | signals.keys).sort.map { |n| finding(n, del_modelo[n], Array(signals[n])) }
  end

  def finding(numero, juicio, senales)
    base = { n: numero, said: turn(numero).content.squish.truncate(240), signals: senales }
    return base.merge(verdict: 'mal', cause: senales.first[:cause], already_fixed: senales.all? { |s| s[:already_fixed] }) if juicio.nil?

    base.merge(judgement(juicio)).merge(proven_cause(senales))
  end

  # Lo comprobado le gana a la opinión: si el agendado del motor tomó el turno, la
  # respuesta entera es eso, diga lo que diga el modelo (lo culpaba al Entrenamiento).
  def proven_cause(senales)
    tomado = senales.find { |s| s[:code] == 'calendar_took_over' }
    tomado ? { cause: tomado[:cause] } : {}
  end

  def judgement(juicio)
    texto = ->(campo) { juicio[campo].to_s.strip.truncate(500) }
    { verdict: juicio['veredicto'], cause: CAUSES.include?(juicio['causa']) ? juicio['causa'] : 'entrenamiento',
      what: texto.call('que_paso'), expected: texto.call('que_se_esperaba'), fix: texto.call('arreglo'),
      already_fixed: juicio['ya_corregido'] == true }
  end

  def judged(verdict)
    Array(verdict['turnos']).select { |f| bot_numbers.include?(f['n'].to_i) && (VERDICTS + ['bien']).include?(f['veredicto']) }
  end

  # { n => [señal] } de las respuestas del bot. Cada una se compara con lo que el motor
  # hace con el mensaje del cliente que contesta (el último antes que ella).
  def signals
    @signals ||= begin
      comprobador = ContactTrackings::Assistant::ReplySignals.new(ran: prompt, current: current_prompt)
      ultimo = nil
      @evidence.turns.each_with_object({}) do |t, acc|
        ultimo = @engine.to_h[t.n] if t.role == 'cliente'
        next unless t.role == 'bot'

        found = comprobador.call(t.content, ultimo)
        acc[t.n] = found if found.any?
      end
    end
  end

  def current_prompt
    @evidence.stale_copy? ? @evidence.template.complementary_prompt.to_s : nil
  end
end
