# frozen_string_literal: true

# ================================================================================
# feat/licencias F6.2 — AGREGAR AGENTES A LA LICENCIA VIGENTE
# ================================================================================
# Plan: docs/licencias_plan_v1.md, F6 (D6a). Sube el tope de agentes de la licencia ACTIVA sin
# emitir otra (p. ej. 5 → 7). Solo sube: bajarlo es asignar una licencia nueva, así nunca deja a
# alguien fuera de golpe. El cambio queda en el registro de la cuenta (AccountLicense es
# `audited`): quién, cuándo, de cuánto a cuánto y el motivo como comentario.
# ================================================================================
class Licenses::AgentIncrease
  class Invalid < StandardError; end

  MAX_ADD = 1000
  MAX_REASON = 255

  pattr_initialize [:license!, :add!, :reason]

  def perform
    raise Invalid, I18n.t('licenses.errors.only_active') unless license.active?
    raise Invalid, I18n.t('licenses.errors.add_agents_count') unless cantidad.between?(1, MAX_ADD)

    license.audit_comment = reason.to_s.squish.truncate(MAX_REASON).presence
    license.update!(max_agents: license.max_agents + cantidad)
    license
  end

  private

  def cantidad
    @cantidad ||= Integer(add, exception: false).to_i
  end
end
