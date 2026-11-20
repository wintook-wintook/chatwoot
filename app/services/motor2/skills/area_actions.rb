# frozen_string_literal: true

# «Atención a clientes» — lo que hace cada área (lo usa Motor2::Skills::Areas):
#   - Soporte: con su solución en las fuentes la da; si no, levanta el caso (crear_caso, con severidad
#     → prioridad) o lo pasa al equipo de soporte, según eligió la empresa;
#   - Comercial: información solo con evidencia; la cotización (o contratar, o un vendedor) se registra
#     como oportunidad (registrar_gestion) o se pasa al vendedor; la demo o la visita se agenda (si eligió
#     agendar y hay con quién) o se pasa al vendedor;
#   - Administrativo: no da datos de la cuenta (no los tiene): pide lo que falte y levanta el caso o lo pasa;
#   - Otra: lo pasa al equipo de esa área.
# No repite un caso abierto de la misma clase. En el chat de prueba no crea nada (folio PRUEBA-1).
module Motor2::Skills::AreaActions
  include Motor2::Skills::AreaSales
  include Motor2::Skills::AreaSupport

  SEARCH_FIRST = 'Todavía no: primero búscalo con buscar_en_fuentes. Si ahí está cómo resolverlo, dale los pasos; si no, lo pasas.'
  SEVERITY = { 1 => 'urgent', 2 => 'high', 3 => 'medium' }.freeze # severidad de soporte → prioridad del caso
  CHANNELED = 'Listo, ya se pasó. Escribe un mensaje corto y cálido: qué le pasas y a quién (p. ej. «le paso tu solicitud de ' \
              'visita a nuestro equipo comercial») y que en cuanto puedan lo atienden. Sin preguntas: ya no sigues tú.'
  CASE_DONE = 'Dale el folio y dile que el equipo le da seguimiento. Sin más preguntas ni ofrecer pasarlo con nadie.'

  # ¿Esta área levanta casos? (si no, se pasa al equipo).
  def support_case?
    data = function.area(area_key).to_h
    (area_key == 'support' && data['action'] == 'case') || (area_key == 'admin' && data['case'] == true)
  end

  def area_note
    case area_key
    when 'support' then support_note
    when 'sales' then sales_note
    when 'admin' then admin_note
    when 'other' then "Es para el equipo de #{area_title}: dile que con gusto lo pasas y llama canalizar."
    else 'Si solo saluda o platica, contesta breve y pregúntale en qué le puedes ayudar.'
    end
  end

  private

  def admin_note
    rest = support_case? ? 'levanta su caso con crear_caso y dale el folio' : 'llama canalizar'
    'Administrativo: tú no ves saldos, facturas ni pagos; no inventes montos ni fechas. Si falta un dato para la gestión ' \
      "(p. ej. el RFC correcto o el folio de la factura) pídelo en una sola pregunta; con eso #{rest}."
  end

  def appointments_on? = @turn.find_skill('appointments').present?

  def channel(reason)
    return { ok: true, nota: 'Ya quedó registrado: NO hace falta pasarlo. Solo dile que su vendedor le da seguimiento.' } if @acted
    return { error: SEARCH_FIRST } if search_first?
    return { error: Motor2::Skills::SupportFlow::SOLUTION_FIRST } if solution_first?

    state['handoff_area'] = area_key
    @turn.decide('handoff', "#{area_title}: #{reason}")
    { ok: true, nota: no_docs_note + CHANNELED + queue_line }
  end

  def queue_line = queue.any? ? " Lo otro que pidió (#{queue.pluck('intencion').join('; ')}) también se lo pasas: díselo." : ''

  def create_case(args)
    return { error: 'Esta área no levanta casos: llama canalizar.' } unless support_case?
    return { error: ASK_FIRST } if ask_first?
    return { error: case_blocker } if case_blocker

    @acted = true
    return { ya_existe: true, folio: state['case_folio'], nota: 'Ya le levantaste este caso: dale ese folio.' } if state['case_folio']
    return test_case if test?

    open_case(args, case_type_for(area_key, :support))
  end

  ASK_FIRST = 'Todavía no: primero pregúntale desde cuándo pasa o a cuántos afecta (una sola pregunta). Con su respuesta lo levantas.'

  # Soporte con «pedir detalles»: el caso se levanta después de una pregunta (salvo que no pueda operar).
  def ask_first?
    area_key == 'support' && function.area('support').to_h['details'] != false && state['area_turns'].to_i.zero? &&
      now['severidad'] != 1 && !@escalate
  end

  def open_case(args, type_id)
    existing = open_ticket(type_id)
    return { ya_existe: true, folio: existing.try(:folio) || existing.id, nota: 'Ya tiene ese caso abierto: dale ese folio.' } if existing

    ticket = new_case(args['titulo'], args['descripcion'], type_id, priority)
    state['case_folio'] = ticket.try(:folio) || ticket.id
    trace.event(:caso, "#{area_title}: #{ticket.title}")
    case_files(type_id)
    { ok: true, folio: ticket.try(:folio) || ticket.id, nota: no_docs_note + CASE_DONE }
  end

  # Los archivos de «al levantar un caso» (instructivo, formato…) van con el mensaje del folio.
  def case_files(type_id)
    type = config.account.case_types.find_by(id: type_id)
    config.template.files_for_ticket(type&.name).first(Motor2::Skills::Files::MAX_PER_MESSAGE).each { |name| @turn.attach(name) }
  end

  def test_case
    case_files(case_type_for(area_key, :support))
    state['case_folio'] = 'PRUEBA-1'
    { ok: true, prueba: true, folio: 'PRUEBA-1', nota: no_docs_note + CASE_DONE }
  end

  def new_case(title, description, type_id, prio)
    target = function.handoff_target(area_key)
    ticket = orchestrator.create_for_manual(title: title.to_s.first(200), description: description.to_s.first(4000), case_type_id: type_id,
                                            priority: prio, assignee_id: target[:user_id], team_id: target[:team_id],
                                            **case_classification)
    state['case_id'] = ticket.id
    ticket
  end

  # Su caso vigente del mismo tipo (no se levanta otro igual).
  def open_ticket(type_id)
    contact = @turn.conversation&.contact
    return nil unless contact

    CaseTicket.where(account_id: config.account.id, contact_id: contact.id, case_type_id: type_id)
              .where.not(status: CaseTicket::CLOSED_STATUSES).order(created_at: :desc).first
  end

  def case_type_for(key, klass)
    function.area(key).to_h['case_type_id'].presence ||
      config.account.case_types.active.where(case_class: klass).order(:id).pick(:id)
  end

  def priority = SEVERITY[now['severidad'].to_i]

  def orchestrator
    Cases::OrchestratorService.new(account: config.account, contact: @turn.conversation&.contact, conversation: @turn.conversation)
  end
end
