# frozen_string_literal: true

# Asistente (Dali) — D4: casos y clientes hablando. Lectura (tipos de caso que el
# usuario puede crear; etapas y motivos de un caso) y propuestas (crear caso u
# oportunidad, mover de etapa, ganar/perder/cancelar, posponer o retomar, cambiar
# datos de la oportunidad o el compromiso, crear contacto). Las propuestas llevan
# en `labels.rows` lo que la tarjeta muestra y en `labels.options` las listas para
# elegir (etapas, motivos). Se incluye en Assistant::Tools.
module Assistant::CaseTools
  OUTCOMES = %w[won lost cancelled].freeze
  OPPORTUNITY_FIELDS = %w[amount currency expected_close_at probability committed commit_note].freeze

  def tool_list_case_types(_args)
    { case_types: writable_types.map do |type|
      { id: type.id, name: type.name, class: type.case_class,
        required_fields: type.case_type_fields.where(required: true).pluck(:label) }
    end }
  end

  def tool_case_options(args)
    ticket = cases.find(args['case_id'])
    { case: ticket.folio, status: ticket.status, opportunity: ticket.commercial?,
      stages: stages_of(ticket), reasons: OUTCOMES.index_with { |o| reasons_for(o) }.merge('postponed' => reasons_for('postponed')) }
  end

  # --- propuestas --------------------------------------------------------------------
  def prepare_create_case(args)
    type = writable_types.find { |t| t.id == args['case_type_id'].to_i }
    raise ArgumentError, 'Elige un tipo de caso de la lista (list_case_types).' unless type

    check_creatable!(type, args)

    contact = contacts.find(args['contact_id'])
    payload = args.slice('title', 'description', 'amount', 'currency', 'expected_close_at')
                  .merge('case_type_id' => type.id, 'contact_id' => contact.id)
    [payload, { 'rows' => [['TYPE', type.name], ['CLIENT', contact.name], ['AMOUNT', money(args)]].select(&:last) }]
  end

  def prepare_move_stage(args)
    ticket = case_for_change(args)
    column = ticket.case_type&.case_type_columns&.find_by(id: args['column_id'])
    raise ArgumentError, 'Elige una etapa de la lista (case_options).' unless column
    raise ArgumentError, 'Esa etapa es un resultado: usa ganar/perder/cancelar.' if column.outcome.present?

    [{ 'case_id' => ticket.id, 'column_id' => column.id },
     { 'target' => case_label(ticket), 'rows' => [['STAGE', column.label]], 'options' => { 'stages' => stages_of(ticket) } }]
  end

  def prepare_outcome(args)
    ticket = case_for_change(args)
    raise ArgumentError, 'Solo las oportunidades se cierran como ganada, perdida o cancelada.' unless ticket.commercial?
    raise ArgumentError, 'Resultado no válido: won, lost o cancelled.' unless OUTCOMES.include?(args['outcome'].to_s)

    outcome = args['outcome'].to_s
    [{ 'case_id' => ticket.id, 'outcome' => outcome, 'reason_id' => args['reason_id'], 'note' => args['note'].to_s,
       'pending_tasks' => args['pending_tasks'] == 'cancel' ? 'cancel' : 'keep' },
     { 'target' => case_label(ticket), 'rows' => [['OUTCOME', outcome]], 'pending' => ticket.case_tasks.pending.count,
       'options' => { 'reasons' => reasons_for(outcome) } }]
  end

  def prepare_postpone(args)
    ticket = case_for_change(args)
    raise ArgumentError, 'Solo una oportunidad se pospone.' unless ticket.commercial?

    date = parse_local(args['until'].to_s)&.to_date
    raise ArgumentError, 'Dime hasta qué fecha (YYYY-MM-DD).' unless date && date > Date.current

    [{ 'case_id' => ticket.id, 'until' => date.iso8601, 'reason_id' => args['reason_id'], 'reason' => args['reason'].to_s },
     { 'target' => case_label(ticket), 'options' => { 'reasons' => reasons_for('postponed') } }]
  end

  def prepare_resume_case(args)
    ticket = case_for_change(args)
    raise ArgumentError, 'Esa oportunidad no está pospuesta.' unless ticket.try(:postponed?)

    [{ 'case_id' => ticket.id }, { 'target' => case_label(ticket) }]
  end

  def prepare_update_opportunity(args)
    ticket = case_for_change(args)
    raise ArgumentError, 'Solo las oportunidades tienen monto, cierre y compromiso.' unless ticket.commercial?

    data = args.slice(*OPPORTUNITY_FIELDS).compact
    raise ArgumentError, 'No me dijiste qué cambiar.' if data.empty?

    [{ 'case_id' => ticket.id }.merge(data),
     { 'target' => case_label(ticket), 'rows' => data.map { |k, v| [k.upcase, v.to_s] } }]
  end

  def prepare_create_contact(args)
    raise ArgumentError, 'Falta el nombre del contacto.' if args['name'].blank?
    raise ArgumentError, 'Dame al menos un correo o un teléfono.' if args['email'].blank? && args['phone'].blank?

    org = args['organization_id'].present? ? organizations.find(args['organization_id']) : nil
    [args.slice('name', 'email', 'phone').merge('organization_id' => org&.id),
     { 'rows' => [['ORGANIZATION', org&.name]].select(&:last) }]
  end

  # Caso que el usuario puede cambiar (su clase en escritura y no cerrado).
  def case_for_change(args)
    ticket = cases.find(args['case_id'])
    raise ArgumentError, 'No tienes permiso para cambiar ese caso.' unless @grant.case_writable?(ticket)
    raise ArgumentError, 'El caso está cerrado: se reabre con el botón Reabrir.' if ticket.frozen_for_edit?

    ticket
  end

  private

  def check_creatable!(type, args)
    required = type.case_type_fields.where(required: true).pluck(:label)
    raise ArgumentError, "Ese tipo pide campos obligatorios (#{required.join(', ')}): créalo desde la pantalla." if required.any?
    raise ArgumentError, 'Falta el título.' if args['title'].blank?
  end

  def writable_types
    @account.case_types.select { |t| @grant.writable?(Access::Grant.area_for_case_class(t.case_class || 'support')) }
  end

  def stages_of(ticket)
    Array(ticket.case_type&.case_type_columns&.order(:position)).map do |c|
      { id: c.id, label: c.label, outcome: c.outcome, current: c.id == ticket.case_type_column_id }
    end
  end

  def reasons_for(outcome)
    @account.case_outcome_reasons.public_send("outcome_#{outcome}").enabled.map { |r| { id: r.id, label: r.label } }
  rescue NoMethodError
    []
  end

  def case_label(ticket) = "#{ticket.folio} · #{ticket.title}"

  def money(args)
    args['amount'].present? ? "#{args['amount']} #{args['currency'].presence || 'MXN'}" : nil
  end
end
