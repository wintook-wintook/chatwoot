# frozen_string_literal: true

# Probador de agentes — la pestaña «Revisión» de quien entrena: los 👎 juntos por plática (se
# revisan mensaje por mensaje) y, de cada uno, cuántos otros pendientes apuntan a la misma
# respuesta predefinida (un solo arreglo los cierra a todos: «Corregido · probar de nuevo» de
# varios a la vez).
#
#   AgentTester::Review.group(logs)
#   → [{ conversation_id:, template_id:, agent:, tester:, last_at:, open:, total:, logs: [AgentTestLog],
#        same_canned: { log_id => [ids de los otros pendientes con la misma predefinida] } }]
module AgentTester::Review
  module_function

  def group(logs)
    mismos = same_canned(logs)
    grupos = logs.group_by(&:conversation_id).map { |conversation_id, grupo| entry(conversation_id, grupo.sort_by(&:id), mismos) }
    grupos.sort_by { |g| [-g[:open], -g[:last_at].to_i] }
  end

  def entry(conversation_id, grupo, mismos)
    primero = grupo.first
    { conversation_id: conversation_id, template_id: primero.tracking_template_id, agent: primero.tracking_template&.name,
      tester: primero.user&.name, last_at: grupo.map(&:created_at).max, open: grupo.count { |l| open?(l) },
      total: grupo.size, logs: grupo, same_canned: grupo.to_h { |l| [l.id, mismos[canned_of(l)].to_a - [l.id]] } }
  end

  def same_canned(logs)
    logs.select { |l| open?(l) && canned_of(l) }.group_by { |l| canned_of(l) }.transform_values { |ls| ls.map(&:id) }
  end

  def canned_of(log) = log.diagnosis.to_h['canned_id']

  def open?(log) = AgentTestLog::OPEN.include?(log.status)
end
