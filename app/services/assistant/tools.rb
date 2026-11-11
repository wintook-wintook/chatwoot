# frozen_string_literal: true

# Asistente (Dali) — lo que el asistente puede hacer, como funciones para el modelo.
#
# Dos clases de funciones:
#   • de LECTURA (buscar, ver un caso o un contacto, la agenda, abrir una pantalla):
#     se ejecutan al momento y su resultado vuelve al modelo;
#   • de PROPUESTA (nota, tarea, tarea agendada, mensaje programado, borrador): NO
#     hacen nada; dejan una propuesta que el usuario confirma (Assistant::Executor).
#
# Todo pasa por los permisos de quien pregunta (Access::Grant): el asistente ve y
# propone solo lo que esa persona podría ver y hacer.
class Assistant::Tools
  include Assistant::ToolRefs
  include Assistant::DelegationTools # D3
  include Assistant::FollowUpTools # Seguimiento IA
  include Assistant::CaseTools # D4
  include Assistant::SalesTools # D5a
  include Assistant::GuideTools # guías de uso de la plataforma
  include Assistant::QuoteTools # cotizaciones
  include Assistant::ConversationTools # contestar conversaciones
  include Assistant::FieldTools # trabajo en campo
  include Assistant::EventTools # NFC en la expo
  include Assistant::ClientTaskTools # tareas con el cliente
  include Assistant::AgendaTools # my_agenda
  include Assistant::CancelTools # cancelar con motivo
  include Assistant::ConvertTools # tarea ↔ tarea agendada
  include Assistant::FollowUpPresetTools # plantillas de seguimiento
  include Assistant::ProgressTools # reportar avance de una tarea

  LIST_LIMIT = 6
  ACTIVITY_LINES = 15

  READ_TOOLS = %w[search get_case get_contact my_agenda open_page list_agents tracking_status
                  list_case_types case_options search_guides read_guide report_gap].freeze +
               QUOTE_READ_TOOLS + CONVERSATION_READ_TOOLS + FIELD_READ_TOOLS + EVENT_READ_TOOLS +
               CLIENT_TASK_READ_TOOLS + FOLLOW_UP_PRESET_READ_TOOLS + PROGRESS_READ_TOOLS
  PROPOSAL_TOOLS = %w[propose_note propose_task propose_meeting propose_scheduled_message propose_draft
                      propose_delegate propose_tracking_action propose_create_case propose_move_stage
                      propose_outcome propose_postpone propose_resume_case propose_update_opportunity
                      propose_create_contact propose_follow_up propose_follow_up_action].freeze +
                   QUOTE_PROPOSAL_TOOLS + CONVERSATION_PROPOSAL_TOOLS + FIELD_PROPOSAL_TOOLS + EVENT_PROPOSAL_TOOLS +
                   CLIENT_TASK_PROPOSAL_TOOLS + CANCEL_PROPOSAL_TOOLS + CONVERT_PROPOSAL_TOOLS + FOLLOW_UP_PRESET_PROPOSAL_TOOLS +
                   PROGRESS_PROPOSAL_TOOLS

  def self.definitions = Assistant::ToolDefinitions.all

  def initialize(account:, user:, grant:, zone:)
    @account = account
    @user = user
    @grant = grant
    @zone = zone
  end

  # → { result: <hash para el modelo>, proposal: <hash>|nil, navigate: <ruta>|nil }
  def call(name, args)
    args = (args || {}).stringify_keys
    return sales_tool(name, args) if SALES_TOOLS.include?(name)
    return open_page(args) if name == 'open_page'
    return { result: public_send("tool_#{name}", args) } if READ_TOOLS.include?(name)
    return proposal(name.delete_prefix('propose_'), args) if PROPOSAL_TOOLS.include?(name)

    { result: { error: "función desconocida: #{name}" } }
  rescue ActiveRecord::RecordNotFound
    { result: { error: 'No encontré ese registro o no tienes acceso.' } }
  end

  # --- lectura --------------------------------------------------------------------
  # La misma búsqueda que la lupa (GlobalSearch): todos los campos de contactos,
  # organizaciones y casos, y en qué campo apareció. Menos de 3 letras: por nombre.
  def tool_search(args)
    return short_search(args) if GlobalSearch.normalize(args['query']).length < GlobalSearch::MIN_CHARS

    found = GlobalSearch.new(account: @account, grant: @grant, query: args['query']).call
    { contacts: with_match(found[:contacts], contacts) { |c| contact_ref(c) },
      organizations: found[:organizations][:items].map { |o| o.slice(:id, :name, :match).compact },
      cases: with_match(found[:cases], cases) { |t| case_ref(t) },
      totals: found.transform_values { |group| group[:count] } }
  end

  def with_match(group, scope)
    records = scope.where(id: group[:items].pluck(:id)).index_by(&:id)
    group[:items].filter_map do |item|
      record = records[item[:id]]
      record && yield(record).merge(match: item[:match]).compact
    end
  end

  def short_search(args)
    q = "%#{ActiveRecord::Base.sanitize_sql_like(args['query'].to_s.strip)}%"
    { contacts: contacts.where('contacts.name ILIKE :q OR contacts.email ILIKE :q OR contacts.phone_number ILIKE :q', q: q)
                        .limit(LIST_LIMIT).map { |c| contact_ref(c) },
      organizations: @account.organizations.where('name ILIKE ?', q).limit(LIST_LIMIT).map { |o| { id: o.id, name: o.name } },
      cases: cases.where('case_tickets.folio ILIKE :q OR case_tickets.title ILIKE :q', q: q)
                  .order(updated_at: :desc).limit(LIST_LIMIT).map { |t| case_ref(t) } }
  end

  def tool_get_case(args)
    ticket = find_case(args)
    feed = Cases::ActivityFeed.new(ticket: ticket, zone: @zone).call
    case_ref(ticket).merge(
      description: ticket.description.to_s.truncate(400), assignee: ticket.assignee&.name,
      organization: ticket.organization&.name, due_at: local(ticket.due_at),
      commercial: commercial(ticket), summary: summary_text(feed[:summary]),
      conversations: feed[:conversations].map { |c| conversation_ref(c) },
      recent_activity: feed[:items].first(ACTIVITY_LINES).map { |item| activity_line(item) }
    )
  end

  def tool_get_contact(args)
    contact = contacts.find(args['contact_id'])
    contact_ref(contact).merge(open_cases: open_cases_of(contact), pending_tasks: pending_tasks_of(contact),
                               upcoming: upcoming_of(contact), conversations: conversations_of(contact))
  end

  def open_page(args)
    path = page_path(args['target'], args['id'])
    return { result: { error: 'No puedo abrir esa pantalla.' } } unless path

    { result: { ok: true, opened: path }, navigate: path }
  end

  # --- propuestas -----------------------------------------------------------------
  def proposal(type, args)
    payload, labels = public_send("prepare_#{type}", args)
    { result: { ok: true, proposal: type, waiting_confirmation: true, summary: labels },
      proposal: { 'id' => SecureRandom.hex(6), 'type' => type, 'payload' => payload, 'labels' => labels,
                  'status' => 'pending' } }
  rescue ArgumentError => e
    { result: { error: e.message } }
  end

  def prepare_note(args)
    target = target_for(args, allow_org: false)
    raise ArgumentError, 'La nota necesita un caso o un contacto.' unless target
    raise ArgumentError, 'Falta el texto de la nota.' if args['content'].blank?

    [target[:ids].merge('content' => args['content'].to_s), { 'target' => target[:label] }]
  end

  def prepare_task(args)
    target = target_for(args)
    raise ArgumentError, 'Falta el título de la tarea.' if args['title'].blank?

    assignee = @account.users.find_by(id: args['assignee_id']) || @user
    payload = (target ? target[:ids] : {}).merge('title' => args['title'].to_s.first(255), 'description' => args['description'].to_s,
                                                 'due_at' => due_day(args['due_at']), 'assignee_id' => assignee.id)
    [payload, { 'target' => target&.dig(:label), 'assignee' => assignee.name }]
  end

  def prepare_meeting(args)
    target = target_for(args)
    starts = parse_local(args['starts_at'])
    raise ArgumentError, 'Falta la fecha y hora de inicio (YYYY-MM-DDTHH:MM).' unless starts

    minutes = args['duration_minutes'].to_i.positive? ? args['duration_minutes'].to_i : 30
    payload = (target ? target[:ids] : {}).merge(
      'title' => args['title'].to_s.first(255), 'description' => args['description'].to_s, 'location' => args['location'].to_s,
      'is_visit' => args['is_visit'] == true, 'starts_at' => starts.iso8601, 'ends_at' => (starts + minutes.minutes).iso8601
    )
    [payload, { 'target' => target&.dig(:label), 'google' => google_connected? }]
  end

  def prepare_scheduled_message(args)
    conversation = find_conversation(args['conversation_id'])
    send_at = parse_local(args['send_at'])
    raise ArgumentError, 'Falta la fecha y hora de envío (YYYY-MM-DDTHH:MM).' unless send_at
    raise ArgumentError, 'La fecha de envío ya pasó.' if send_at < Time.current

    [{ 'conversation_id' => conversation.display_id, 'content' => args['content'].to_s, 'send_at' => send_at.iso8601 },
     { 'conversation' => conversation_label(conversation) }]
  end

  def prepare_draft(args)
    conversation = args['conversation_id'].present? ? find_conversation(args['conversation_id']) : nil
    [{ 'conversation_id' => conversation&.display_id, 'content' => args['content'].to_s },
     { 'conversation' => conversation && conversation_label(conversation) }]
  end

  # --- lo que el usuario puede ver --------------------------------------------------
  def contacts = @grant.contacts(@account.contacts)
  def cases = @grant.case_tickets(@account.case_tickets)
  def organizations = @account.organizations

  def find_case(args)
    return cases.find(args['case_id']) if args['case_id'].present?

    cases.find_by!(folio: args['folio'].to_s.strip.upcase)
  end

  # El «a quién»: caso, o contacto/organización. → { ids:, label: } o nil
  def target_for(args, allow_org: true)
    if args['case_id'].present?
      ticket = cases.find(args['case_id'])
      return { ids: { 'case_id' => ticket.id }, label: "#{ticket.folio} · #{ticket.title}" }
    end
    if args['contact_id'].present?
      contact = contacts.find(args['contact_id'])
      return { ids: { 'contact_id' => contact.id }, label: contact.name }
    end
    return unless allow_org && args['organization_id'].present?

    org = @account.organizations.find(args['organization_id'])
    { ids: { 'organization_id' => org.id }, label: org.name }
  end

  private

  # Vence de una tarea: solo el día; vence al final de ese día (la hora es de las agendadas).
  def due_day(value)
    parse_local(value)&.end_of_day&.iso8601
  end

  def parse_local(value)
    return nil if value.blank?

    @zone.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def local(time) = time&.in_time_zone(@zone)&.strftime('%Y-%m-%d %H:%M')

  # El día en que vence una tarea (sin hora: vence al final de ese día).
  def due_on(time) = time&.in_time_zone(@zone)&.strftime('%Y-%m-%d')

  def google_connected?
    UserCalendarIntegration.exists?(account_id: @account.id, user_id: @user.id)
  end

  def page_path(target, id)
    path = Assistant::Pages::MAP[target.to_s]&.call(self, id)
    path && "/app/accounts/#{@account.id}/#{path}"
  end
end
