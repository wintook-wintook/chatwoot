# frozen_string_literal: true

# ================================================================================
# proyecto@ai_agent_assistant - F2
# ================================================================================
# Auditoría de la base instalada: corre el linter sobre los Agentes IA que ya
# existen y dice cuántos están rotos y por qué, ANTES de tocar nada.
#
#   rake ai_agent_assistant:audit          # todas las cuentas con agentes
#   rake ai_agent_assistant:audit[568]     # una cuenta
#
# Solo lee. La lógica vive en AiAgentAssistant::Auditor.
# ================================================================================

namespace :ai_agent_assistant do
  desc 'Audita los Agentes IA existentes con el linter (solo lectura)'
  task :audit, [:account_id] => :environment do |_t, args|
    accounts = AiAgentAssistant::Auditor.accounts_with_agents(args[:account_id])

    if accounts.empty?
      puts 'No hay cuentas con Agentes IA.'
      next
    end

    totals = Hash.new(0)
    accounts.each { |account| AiAgentAssistantAuditPrinter.new(account, totals).print }

    puts ''
    puts '=' * 78
    puts "TOTAL: #{totals[:error]} con error · #{totals[:warning]} con avisos · #{totals[:clean]} limpios"
  end
end

# Impresión del informe. Vive aquí porque solo la usa la tarea.
class AiAgentAssistantAuditPrinter
  def initialize(account, totals)
    @account = account
    @totals  = totals
  end

  def print
    results = AiAgentAssistant::Auditor.new(@account).call
    return if results.empty?

    header(results)
    results.reject { |r| r.status == :clean }.each { |result| print_result(result) }
    footer(AiAgentAssistant::Auditor.summarize(results))
  end

  private

  def header(results)
    puts ''
    puts "Cuenta ##{@account.id} · #{@account.name} · #{results.size} agentes"
    puts '-' * 78
  end

  def print_result(result)
    result.findings.reject { |f| f[:level] == :info }.each do |finding|
      icon = finding[:level] == :error ? 'ERROR' : 'aviso'
      puts format('  %<icon>-5s %<id>-5s %<name>-42s %<rule>s',
                  icon: icon, id: result.template.id,
                  name: result.template.name.to_s.truncate(42), rule: finding[:rule])
      detail = detail_line(finding)
      puts "              #{detail}" if detail.present?
    end
  end

  def detail_line(finding)
    finding[:params].map { |k, v| "#{k}=#{Array(v).first(3).join(', ')}" }.join(' · ')
  end

  def footer(counts)
    puts ''
    puts "  #{counts[:error]} con error bloqueante · #{counts[:warning]} con avisos · #{counts[:clean]} limpios"
    counts.each { |status, n| @totals[status] += n }
  end
end
