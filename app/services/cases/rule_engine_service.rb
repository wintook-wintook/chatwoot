# frozen_string_literal: true

# ================================================================================
# @tickets_cases
# ================================================================================
# Servicio: Cases::RuleEngineService
# Responsabilidad: Evalúa las CaseRules activas de una cuenta en cascada
#                  sobre un CaseTicket dado.
#
# Flujo:
#   1. Carga las reglas activas ordenadas por position (menor = primero)
#   2. Por cada regla: evalúa todas las conditions (AND implícito)
#   3. Si todas coinciden: ejecuta las actions
#   4. Si continue_on_match = false (default): para en el primer match
#
# Condiciones soportadas:
#   Fields:    case_type, origin, priority, status, sla_status,
#              message_content, time_without_response_min
#   Operators: eq, neq, contains, gte, lte, in, not_in
#
# Acciones soportadas:
#   assign_agent, assign_team, change_priority, change_status,
#   escalate, notify_agent, trigger_tracking, add_label, close_ticket
# ================================================================================

class Cases::RuleEngineService
  OPERATORS = {
    'eq'       => ->(v, ref) { v.to_s == ref.to_s },
    'neq'      => ->(v, ref) { v.to_s != ref.to_s },
    'contains' => ->(v, ref) { v.to_s.downcase.include?(ref.to_s.downcase) },
    'gte'      => ->(v, ref) { v.to_f >= ref.to_f },
    'lte'      => ->(v, ref) { v.to_f <= ref.to_f },
    'in'       => ->(v, ref) { Array(ref).map(&:to_s).include?(v.to_s) },
    'not_in'   => ->(v, ref) { !Array(ref).map(&:to_s).include?(v.to_s) }
  }.freeze

  def initialize(ticket, trigger_message: nil)
    @ticket          = ticket
    @trigger_message = trigger_message
  end

  def evaluate!
    CaseRule.where(account: @ticket.account).enabled.each do |rule|
      next unless conditions_match?(rule.conditions)

      Rails.logger.info "[RuleEngine] Regla '#{rule.name}' coincide con ticket ##{@ticket.id}"
      execute_actions!(rule.actions)
      break unless rule.continue_on_match
    end
  rescue StandardError => e
    Rails.logger.error "[RuleEngine] Error evaluando ticket ##{@ticket.id}: #{e.message}"
  end

  private

  def conditions_match?(conditions)
    return true if conditions.blank?

    conditions.all? do |condition|
      fn = OPERATORS[condition['operator']]
      next false unless fn

      fn.call(field_value(condition['field']), condition['value'])
    end
  end

  def field_value(field)
    case field
    when 'case_type'                 then @ticket.case_type_id # @tickets_cases: condición compara contra id
    when 'origin'                    then @ticket.origin
    when 'priority'                  then @ticket.priority
    when 'status'                    then @ticket.status
    when 'sla_status'                then @ticket.sla_status
    when 'message_content'           then @trigger_message&.content.to_s
    when 'time_without_response_min' then elapsed_minutes
    end
  end

  def elapsed_minutes
    ((Time.current - @ticket.created_at) / 60).to_i
  end

  def execute_actions!(actions)
    actions.each do |action|
      execute_single_action(action['type'], action['value'])
    rescue StandardError => e
      Rails.logger.error "[RuleEngine] Acción '#{action['type']}' falló: #{e.message}"
    end
  end

  def execute_single_action(type, value)
    @ticket.reload

    case type
    when 'assign_agent'
      user = find_user(value)
      @ticket.update!(assignee: user, assignee_type: :agent) if user
      log_action(type, "agent #{value}")

    when 'assign_team'
      team = find_team(value)
      @ticket.update!(team: team, assignee_type: :team) if team
      log_action(type, "team #{value}")
      @ticket.case_events.create!(account: @ticket.account, event_type: :assigned,
                                  origin: :system, payload: { team: value })

    when 'change_priority'
      return unless CaseTicket.priorities.key?(value.to_s)

      @ticket.update!(priority: value)
      log_action(type, value)

    when 'change_status'
      return unless @ticket.can_transition_to?(value)

      @ticket.transition!(value)
      log_action(type, value)

    when 'escalate'
      return unless @ticket.can_transition_to?(:escalated)

      @ticket.transition!(:escalated)
      log_action(type, 'escalated')

    when 'close_ticket'
      return unless @ticket.can_transition_to?(:closed)

      @ticket.transition!(:closed)
      log_action(type, 'closed')

    when 'notify_agent'
      # Fase 3: se implementa con notificación en el panel
      log_action(type, value)

    when 'add_label', 'trigger_tracking'
      # Fases posteriores
      log_action(type, value)
    end
  end

  def find_user(value)
    @ticket.account.users.find_by(name: value) ||
      @ticket.account.users.find_by(id: value.to_i)
  end

  def find_team(value)
    @ticket.account.teams.find_by(name: value) ||
      @ticket.account.teams.find_by(id: value.to_i)
  end

  def log_action(type, value)
    Rails.logger.info "[RuleEngine] Acción ejecutada: #{type}=#{value} en ticket ##{@ticket.id}"
  end
end
