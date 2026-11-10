# frozen_string_literal: true

# Asistente (Dali) — D4: hace lo confirmado sobre casos y clientes con las mismas
# piezas que las pantallas: alta manual del caso (Cases::OrchestratorService), mover
# de etapa (misma regla que el Tablero, sin cerrar ni posponer por aquí), cerrar con
# resultado (close_with_outcome!, con la decisión sobre las tareas pendientes),
# posponer/retomar, datos de la oportunidad (assign_commercial_data + su bitácora) y
# alta de contacto. Se incluye en Assistant::Executor.
module Assistant::CaseRunner
  CLOSING = %w[closed resolved validating cancelled].freeze

  def run_create_case(payload)
    type = @account.case_types.find(payload['case_type_id'])
    raise Assistant::Executor::Refused, 'No tienes permiso para crear ese tipo de caso.' unless type_writable?(type)

    contact = @tools.contacts.find(payload['contact_id'])
    ticket = Cases::OrchestratorService.new(account: @account, contact: contact, conversation: nil)
                                       .create_for_manual(title: payload['title'].to_s.first(255), case_type_id: type.id,
                                                          description: payload['description'].presence,
                                                          assignee_id: @user.id, commercial: opportunity_data(payload))
    done("#{type.name} #{ticket.folio} creado", case_path(ticket))
  end

  def run_move_stage(payload)
    ticket = changeable(payload)
    column = ticket.case_type.case_type_columns.find(payload['column_id'])
    raise Assistant::Executor::Refused, 'Esa etapa es un resultado: usa ganar/perder.' if column.outcome.present?

    column.statuses.include?(ticket.status) ? move_within(ticket, column) : move_across(ticket, column)
    done("#{ticket.folio} pasó a «#{column.label}»", case_path(ticket))
  end

  def run_outcome(payload)
    ticket = changeable(payload)
    ticket.pending_tasks_decision = payload['pending_tasks'] == 'cancel' ? 'cancel' : 'keep'
    ticket.close_with_outcome!(payload['outcome'], actor: @user, reason_id: payload['reason_id'].presence,
                                                   note: payload['note'].presence)
    done("#{ticket.folio} cerrada", case_path(ticket))
  rescue RuntimeError => e
    raise Assistant::Executor::Refused, e.message
  end

  def run_postpone(payload)
    ticket = changeable(payload)
    ticket.postpone!(until_date: payload['until'], actor: @user, reason: payload['reason'].presence,
                     reason_id: payload['reason_id'].presence)
    done("#{ticket.folio} pospuesta hasta #{payload['until']}", case_path(ticket))
  rescue RuntimeError => e
    raise Assistant::Executor::Refused, e.message
  end

  def run_resume_case(payload)
    ticket = changeable(payload)
    ticket.resume!(actor: @user)
    done("#{ticket.folio} retomada", case_path(ticket))
  rescue RuntimeError => e
    raise Assistant::Executor::Refused, e.message
  end

  def run_update_opportunity(payload)
    ticket = changeable(payload)
    changes = ticket.assign_commercial_data(payload.slice(*Assistant::CaseTools::OPPORTUNITY_FIELDS))
    ticket.save!
    ticket.log_commercial_change!(changes, actor: @user)
    done("Datos de #{ticket.folio} actualizados", case_path(ticket))
  end

  def run_create_contact(payload)
    org = payload['organization_id'].present? ? @account.organizations.find(payload['organization_id']) : nil
    contact = @account.contacts.create!(name: payload['name'].to_s.strip, email: payload['email'].presence,
                                        phone_number: payload['phone'].presence, organization_id: org&.id,
                                        owner_id: (@user.id if @grant.own?(:clients)))
    done("Contacto #{contact.name} creado", "#{base}/contacts/#{contact.id}")
  end

  private

  def changeable(payload)
    @tools.case_for_change(payload)
  rescue ArgumentError => e
    raise Assistant::Executor::Refused, e.message
  end

  def type_writable?(type)
    @grant.writable?(Access::Grant.area_for_case_class(type.case_class || 'support'))
  end

  def opportunity_data(payload)
    payload.slice('amount', 'currency', 'expected_close_at').compact_blank
  end

  # Misma regla que el Tablero: dentro del mismo estado solo cambia la etapa.
  def move_within(ticket, column)
    from = ticket.case_type_column_id
    ticket.update!(case_type_column_id: column.id)
    ticket.case_events.create!(account: @account, event_type: :column_changed, origin: :agent, actor: @user,
                               payload: { from: from, to: column.id, status: ticket.status })
  end

  def ends_work?(ticket, target)
    target.nil? || CLOSING.include?(target) || (ticket.commercial? && target == 'waiting_on_customer')
  end

  # A otro estado: nunca cierra ni pospone desde aquí (eso va con su propia tarjeta).
  def move_across(ticket, column)
    statuses = column.statuses - (ticket.commercial? ? CaseTicket::COMMERCIAL_BLOCKED_STATUSES : [])
    target = statuses.find { |s| ticket.can_transition_to?(s) } || statuses.first
    raise Assistant::Executor::Refused, 'Esa etapa cierra o pospone el caso: hazlo con su opción o desde la pantalla.' if ends_work?(ticket, target)

    ActiveRecord::Base.transaction do
      ticket.transition!(target, actor: @user, force: true)
      ticket.update!(case_type_column_id: column.id)
    end
  end
end
