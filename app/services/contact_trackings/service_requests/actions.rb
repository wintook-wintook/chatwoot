# frozen_string_literal: true

# ================================================================================
# proyecto@solicitudes — CONFIRMAR, CANCELAR Y MOVER POR SERVICIO (pieza 5, F4, 26/09/2026)
# ================================================================================
# Con varios servicios abiertos en la conversación, el cliente dice a cuál se refiere:
#   por número   «confirmo el 1 y el 3», «cancela el 2», «2️⃣»
#   por equipo   «cancela el hiab», «la plana pásala a las 10»
#   sin decir    confirmar → todos los apartados; cancelar/mover con varios → «¿cuál?»
#
#   confirmar  la ruta tiene @confirmar_servicio → en firme (quita «[TENTATIVO]»); con
#              (requiere=pago) queda «esperando pago»: lo deja en firme la etiqueta
#              «pago_confirmado» (todos) o mover el caso a la columna «Pagado» (uno)
#   cancelar   «cancela», «anula», «ya no lo necesito» → tarea y caso cancelados
#   mover      «pásalo / muévelo / reprograma … <fecha u hora>» → nuevas opciones (2A, 2B…)
#
# nil = no hay servicios abiertos o el mensaje no es ninguna de las tres: el motor sigue.
# ================================================================================

class ContactTrackings::ServiceRequests::Actions
  CANCEL_RE = /\b(cancel\w*|anul\w*|ya no (?:va|lo|la|los|las|necesit\w*))\b/i
  MOVE_RE = /\b(p[aá]s[ae]\w*|mueve\w*|mover\w*|cambia\w*|reprogram\w*|recorre\w*)\b/i
  REF_RE = %r{(?:\bel|\bla|\blos|\blas|\by|servicio|n[uú]mero|#)\s*([1-9])\b(?!\s*(?:de|:|/|-|hrs?|am|pm))|([1-9])️?⃣}i

  def initialize(tracking:, message:, branch:, timezone:)
    @tracking = tracking
    @message = message
    @branch = branch
    @timezone = timezone
    @texto = message.content.to_s
  end

  def call
    @casos = ContactTrackings::ServiceRequests::Registry.open_cases(@message.conversation).to_a
    return nil if @casos.empty?
    return confirm if confirm_route? && with_state('apartado').any?
    return cancel if @texto.match?(CANCEL_RE)

    move if moving?
  end

  # «pásalo al martes», «muévelo a las 10»: el verbo y una fecha u hora nueva.
  def moving?
    @texto.match?(MOVE_RE) && (new_date.date.present? || new_date.time.present?)
  end

  private

  def confirm_route?
    @branch&.escalation.to_s.match?(ContactTrackings::ServiceConfirmation::DIRECTIVE_RE)
  end

  def with_state(*estados)
    @casos.select { |caso| estados.include?(caso.metadata['estado']) }
  end

  # ── confirmar ────────────────────────────────────────────────────────────────
  def confirm
    candidatos = with_state('apartado')
    elegidos = referenced(candidatos) || candidatos
    return ask_payment(elegidos) if ContactTrackings::ServiceConfirmation.requires_payment?(@branch.escalation)

    lineas = elegidos.map do |caso|
      ok = ContactTrackings::ServiceMeeting.new(meeting(caso)).confirm!
      mark(caso, ok ? 'confirmado' : 'apartado')
      "#{number(caso)} #{label(caso)}#{ok ? '' : ' — un asesor lo confirma'}"
    end
    "✅ Confirmé:\n#{lineas.join("\n")}"
  end

  def ask_payment(elegidos)
    elegidos.each { |caso| mark(caso, 'esperando_pago') }
    numeros = elegidos.map { |caso| number(caso) }.join(', ')
    note("💳 El cliente confirmó #{numeros}; falta el pago. Al recibirlo pon la etiqueta " \
         "«#{ContactTrackings::ServiceConfirmation::PAID_LABEL}» (todos) o mueve el caso a la columna «Pagado» (solo ese).")
    "¡Gracias por confirmar! Para dejar en firme #{numeros} necesitamos el pago por adelantado. " \
      'En cuanto lo recibamos, te lo confirmo.'
  end

  # ── cancelar ─────────────────────────────────────────────────────────────────
  def cancel
    elegidos = referenced(@casos) || (@casos.one? ? @casos : nil)
    return which('cancelar') if elegidos.nil?

    lineas = elegidos.map { |caso| "#{number(caso)} #{label(caso)} (caso #{caso.folio.presence || caso.id})" }
    elegidos.each { |caso| cancel_case(caso) }
    "Listo, cancelé:\n#{lineas.join("\n")}"
  end

  def cancel_case(caso)
    tarea = meeting(caso)
    ContactTrackings::ServiceMeeting.new(tarea).cancel! if tarea && !tarea.cancelled?
    caso.transition!(:cancelled, reason: 'El cliente canceló el servicio', force: true)
    mark(caso, 'cancelado')
  end

  # ── mover ────────────────────────────────────────────────────────────────────
  def move
    elegidos = referenced(@casos) || (@casos.one? ? @casos : nil)
    return which('mover') if elegidos.nil?

    agenda = ContactTrackings::ServiceRequests::Scheduler.new(tracking: @tracking, route: solicitudes_route, timezone: @timezone)
    lineas = elegidos.map { |caso| reschedule(caso, agenda) }
    "#{lineas.join("\n")}\n\nResponde con el horario que quieres (por ejemplo «#{elegidos.first && "#{position(elegidos.first)}A"}»)."
  end

  def reschedule(caso, agenda)
    datos = caso.metadata['servicio'].merge({ 'date' => new_date.date&.iso8601, 'time' => new_date.time }.compact)
    caso.update!(metadata: caso.metadata.merge('servicio' => datos))
    plan = agenda.plan(caso, position(caso))
    opciones = plan.offers.map { |oferta| option_text(oferta) }.join(' · ').presence
    "#{number(caso)} #{label(caso)}: #{[plan.note, opciones].compact.join(' → ')}"
  end

  def option_text(oferta)
    inicio = Time.zone.parse(oferta['slot']).in_time_zone(@timezone)
    "#{oferta['code']} #{inicio.strftime('%d/%m %H:%M')} (#{oferta['calendar_name']})"
  end

  def new_date
    @new_date ||= ContactTrackings::ServiceRequests::DateResolver.new(timezone: @timezone).call(@texto, @texto)
  end

  def solicitudes_route
    ContactTrackings::RouteMap.parse(@tracking.complementary_prompt).routes
                              .find { |ruta| ContactTrackings::ServiceRequests::Turn.route?(ruta.escalation) }
  end

  # ── a cuál se refiere ────────────────────────────────────────────────────────
  # Por número («el 1 y el 3», «2️⃣») o por equipo («el hiab»). nil si no nombró ninguno.
  def referenced(candidatos)
    numeros = @texto.scan(REF_RE).flatten.compact.map(&:to_i)
    por_numero = candidatos.select { |caso| numeros.include?(position(caso)) }
    return por_numero if por_numero.any?

    texto = fold(@texto)
    por_equipo = candidatos.select { |caso| (kind = kind_of(caso)) && texto.include?(kind) }
    por_equipo.presence
  end

  def kind_of(caso)
    datos = caso.metadata['servicio'].to_h
    etiqueta = fold("#{datos['equipment_type']} #{datos['label']}")
    ContactTrackings::ServiceRequests::Registry::KINDS.find { |kind| etiqueta.include?(kind) }
  end

  def which(accion)
    lista = @casos.map { |caso| "#{number(caso)} #{label(caso)}" }.join("\n")
    "¿Cuál quieres #{accion}?\n#{lista}"
  end

  # ── utilidades ───────────────────────────────────────────────────────────────
  def meeting(caso)
    CaseMeeting.find_by(id: caso.metadata['meeting_id'])
  end

  def mark(caso, estado)
    caso.update!(metadata: caso.metadata.merge('estado' => estado))
  end

  def note(texto)
    Messages::MessageBuilder.new(bot_user, @message.conversation,
                                 { content: texto, private: true, message_type: 'outgoing' }).perform
  end

  def bot_user
    account = @message.account
    account.users.first || AccountUser.where(account_id: account.id).first&.user || User.first
  end

  def position(caso)
    @casos.index { |c| c.id == caso.id }.to_i + 1
  end

  def number(caso)
    ContactTrackings::ServiceRequests::Turn::NUMBERS.fetch(position(caso), "#{position(caso)}.")
  end

  def label(caso)
    caso.metadata.dig('servicio', 'label').presence || caso.title
  end

  def fold(text)
    I18n.transliterate(text.to_s).downcase
  end
end
