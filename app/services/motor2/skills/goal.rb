# frozen_string_literal: true

# «Atención a clientes» › «¿Qué quieres que logre?» (answers['goal'], Motor2::Functions::Customers#skills): el agente
# atiende como siempre y, además, lleva la plática hacia la meta de la empresa sin perder el hilo:
#   appointment  que agende su cita (Motor2::Skills::Appointments)
#   quote        que salga con su cotización (Motor2::Skills::Quote)
# Modo (answers['goal_mode']):
#   soft    invita solo después de dar información comercial (precios, servicios, informes)
#   active  también después de saludar o platicar (nunca en soporte, administrativo, quejas ni si pide una persona)
# La invitación la asegura el código: si el mensaje de información no trae pregunta, se agrega una al final.
# Si dice que no, ya no se le vuelve a invitar en la plática; si ya lo logró, deja de invitar (puede mover o cancelar).
# Si deja de contestar, el recordatorio (Motor2::FollowUp, modo :attempt) lo retoma con la meta.
# Etiquetas: objetivo-pendiente mientras no lo logra; objetivo-logrado al lograrlo (Motor2::Labels quita la pendiente).
#
#   skills.goal = { 'on' => true, 'goal' => 'appointment', 'mode' => 'soft' }
#   memoria: state['goal_declined'] (le invitó y dijo que no), state['goal_done'] (lo logró; en «Probar»)
class Motor2::Skills::Goal < Motor2::Skills::Base
  GOALS = %w[appointment quote].freeze
  MODES = %w[soft active].freeze
  TEXT = {
    'appointment' => { meta: 'que agende su cita', invite: '¿Te busco un horario?', done_tool: 'agendar_cita',
                       gestion: 'cita', tools: %w[ver_horarios agendar_cita mover_cita cancelar_cita],
                       asks: /¿[^¿?]*(horario|agend|cita|apart|lugar)[^¿?]*\?/i },
    'quote' => { meta: 'que salga con su cotización formal', invite: '¿Te preparo la cotización?', done_tool: 'cotizar',
                 gestion: 'cotizacion', tools: %w[cotizar], asks: /¿[^¿?]*cotiz[^¿?]*\?/i }
  }.freeze
  DECLINE = /\A\s*(no\b(?!\s+s[eé]\b)|nel\b|ahorita\s+no|ahora\s+no|todav[ií]a\s+no|luego|despu[eé]s|m[aá]s\s+adelante|
              lo\s+pienso|lo\s+voy\s+a\s+pensar|por\s+ahora\s+no|solo\s+(quer[ií]a|estoy)\s+(saber|viendo|preguntando))/xi
  INFO_GESTIONES = [nil, '', 'info'].freeze

  def self.key = 'goal'

  # Su último mensaje lo invitaba (a agendar o cotizar) y contestó que no: ya no se le invita en la plática.
  def prepare(history)
    list = Array(history)
    return unless list.last && list.last[:role].to_s == 'user' && list.last[:content].to_s.match?(DECLINE)

    invited = list[0...-1].reverse.find { |m| m[:role].to_s == 'assistant' }&.dig(:content).to_s.match?(TEXT[goal][:asks])
    state['goal_declined'] = true if invited
  end

  def turn_note
    return attempt_note if @turn.mode == :attempt
    return "META LOGRADA (#{meta}): ya no lo invites a eso; ayúdale con lo que pida (#{after_text})." if achieved?
    return "Ya dijo que por ahora no (#{meta}): no lo vuelvas a invitar; contesta lo que pida." if declined?
    return nil unless invite_now?

    "META DE LA EMPRESA: #{meta}. Contesta lo que pidió y cierra con UNA invitación breve y natural a eso " \
      "(por ejemplo «#{invite}»), sin presionar."
  end

  # El mensaje de información que no trae pregunta: se cierra con la invitación.
  def polish(reply)
    return reply unless @turn.mode == :reply && @turn.decision.nil? && invite_now? && reply.present?
    return reply if reply.include?('¿')

    "#{reply.strip}\n\n#{invite}"
  end

  def labels
    return [] unless @turn.mode == :reply

    achieved? ? ['objetivo-logrado'] : ['objetivo-pendiente']
  end

  private

  def goal = setting(:goal).to_s.presence_in(GOALS) || 'appointment'

  def mode = setting(:mode).to_s.presence_in(MODES) || 'soft'

  def meta = TEXT[goal][:meta]

  # Con «su cuenta» (Motor2::Skills::QuoteCart) el paso hacia la meta es irla armando: primero «¿Te lo agrego a tu
  # cuenta?» y, con cosas en ella, «¿Te agendo todo?» (o la cotización).
  def invite
    return TEXT[goal][:invite] unless cart_on?
    return '¿Te lo agrego a tu cuenta?' if Array(state['cart']).empty? && !state['cart_declined']

    goal == 'appointment' ? '¿Te agendo todo?' : '¿Te preparo la cotización?'
  end

  def cart_on? = @turn.find_skill('quote')&.cart? == true

  def after_text = goal == 'appointment' ? 'puedes mover o cancelar su cita' : 'resuelve sus dudas de la cotización'

  # Lo logró en este mensaje (la herramienta salió bien) o antes: la cita sigue agendada o ya tiene cotización.
  # En «Probar» no se crea nada: cuenta lo que quedó en la memoria.
  def achieved?
    state['goal_done'] = true if trace.tools.any? { |t| t['name'] == TEXT[goal][:done_tool] && t['ok'] }
    return state['goal_done'] == true if test? || goal == 'quote'

    appointment_booked?
  end

  # Alguna de sus citas sigue agendada (Motor2::Skills::AppointmentList).
  def appointment_booked?
    ids = [*Array(state['appointments']).pluck('meeting_id'), state.dig('appointment', 'meeting_id')].compact
    ids.any? && CaseMeeting.exists?(id: ids, status: :scheduled)
  end

  def declined? = state['goal_declined'] == true

  # Toca invitar: no lo ha logrado ni dijo que no, y es información comercial (o, en modo activo, saludo o plática).
  def invite_now?
    return false if achieved? || declined? || doing_goal?

    areas = @turn.find_skill('areas')
    return mode == 'active' if areas.nil?

    !areas.human_asked? && invite_area?(areas)
  end

  def invite_area?(areas)
    case areas.area_key
    when 'sales' then INFO_GESTIONES.include?(areas.now['gestion'])
    when 'none' then mode == 'active'
    else false
    end
  end

  # Ya está en eso (pidió la cita o la cotización, o ya le dio horarios): sigue el flujo de esa habilidad, sin invitar.
  def doing_goal?
    return true if trace.tools.any? { |t| TEXT[goal][:tools].include?(t['name']) }

    areas = @turn.find_skill('areas')
    areas.present? && areas.now['gestion'] == TEXT[goal][:gestion]
  end

  def attempt_note
    return nil if achieved? || declined?

    "Retómalo con la meta (#{meta}): una línea natural, por ejemplo «#{invite}»."
  end
end
