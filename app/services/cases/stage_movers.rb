# frozen_string_literal: true

# ================================================================================
# @tickets_cases — Plan-Plantilla-Tareas-Etapa T4: qué mueve cada etapa de un tipo
# ================================================================================
# Para la pestaña Columnas de Tipos de caso, por etapa:
#   required_count — obligatorias de su plantilla (con su modo deciden la salida)
#   rules_in       — reglas de casos que le traen casos: cambian el estado a uno que
#                    esta etapa pinta (la primera del tipo que lo cubre, como el tablero)
#   warnings       — la etapa avanza sola y una regla también puede cambiarle el
#                    estado a otro: los dos la mueven, hay que revisar que no choquen
# Una regla aplica al tipo salvo que su condición de tipo lo excluya.
# ================================================================================

class Cases::StageMovers
  STATUS_ACTIONS = { 'escalate' => 'escalated', 'close_ticket' => 'closed' }.freeze

  def initialize(case_type)
    @case_type = case_type
  end

  def call
    columns = @case_type.case_type_columns.ordered.includes(:task_templates).to_a
    movers = columns.to_h { |c| [c.id, { required_count: c.task_templates.count(&:required), rules_in: [], warnings: [] }] }
    rule_targets.each do |rule, status|
      target = columns.detect { |c| c.statuses.include?(status) }
      movers[target.id][:rules_in] << { id: rule.id, name: rule.name, status: status } if target
      columns.each { |c| warn_conflict(movers[c.id], c, rule, status) }
    end
    movers
  end

  private

  def warn_conflict(entry, column, rule, status)
    return unless column.advance_automatic? && column.statuses.exclude?(status)
    return if entry[:warnings].any? { |w| w[:id] == rule.id }

    entry[:warnings] << { id: rule.id, name: rule.name }
  end

  # [[regla, estado al que lleva], …] de las reglas activas que aplican al tipo.
  def rule_targets
    CaseRule.where(account_id: @case_type.account_id).enabled.select { |r| applies?(r) }.flat_map do |rule|
      Array(rule.actions).filter_map { |a| target_status(a) }.uniq.map { |status| [rule, status] }
    end
  end

  def target_status(action)
    return action['value'].to_s.presence if action['type'] == 'change_status'

    STATUS_ACTIONS[action['type']]
  end

  def applies?(rule)
    Array(rule.conditions).none? { |c| c['field'] == 'case_type' && excludes?(c) }
  end

  def excludes?(condition)
    id = @case_type.id.to_s
    values = Array(condition['value']).map(&:to_s)
    case condition['operator']
    when 'eq', 'in' then values.exclude?(id)
    when 'neq', 'not_in' then values.include?(id)
    else false
    end
  end
end
