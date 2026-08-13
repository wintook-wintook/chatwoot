# frozen_string_literal: true

# ================================================================================
# proyecto@ai_agent_assistant - F2
# ================================================================================
# Servicio: AiAgentAssistant::Auditor
# Descripción: Corre el linter en lote sobre los Agentes IA que YA existen y
#              resume cuántos están rotos y por qué.
#
# Es un entregable en sí mismo: al terminar F2 se sabe cuántos agentes fallan en
# cada cuenta, sin haber escrito todavía el chat. Solo lee.
#
# Lo consumen la tarea rake y, más adelante, la pestaña de auditoría de la página
# del Asistente.
# ================================================================================

class AiAgentAssistant::Auditor
  Result = Struct.new(:template, :findings, keyword_init: true) do
    def errors
      findings.select { |f| f[:level] == :error }
    end

    def warnings
      findings.select { |f| f[:level] == :warning }
    end

    def status
      return :error if errors.any?
      return :warning if warnings.any?

      :clean
    end
  end

  def initialize(account)
    @account = account
  end

  def call
    @account.tracking_templates.includes(:inbox).ordered.map do |template|
      Result.new(
        template: template,
        findings: AiAgentAssistant::Linter.new(template, account: @account).call
      )
    end
  end

  # Resumen por cuenta: { error: n, warning: n, clean: n }
  def self.summarize(results)
    counts = Hash.new(0)
    results.each { |r| counts[r.status] += 1 }
    counts
  end

  # Cuentas que tienen al menos un Agente IA.
  def self.accounts_with_agents(account_id = nil)
    return Account.where(id: account_id) if account_id.present?

    Account.joins(:tracking_templates).distinct
  end
end
