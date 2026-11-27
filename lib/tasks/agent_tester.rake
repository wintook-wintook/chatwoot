# frozen_string_literal: true

namespace :agent_tester do
  # Una sola vez: antes el probador tomaba cualquier bandeja API sin webhook de la cuenta y sus pláticas
  # quedaron en bandejas reales (cuenta 1128 «AGENTE ESCUELA Test API», 568 «Agents IA DryRun»). Las
  # cierra todas y borra las que no cita la bitácora, con su contacto «Probador · …».
  # ACCOUNT_ID=1128 limita a una cuenta; DRY_RUN=1 solo cuenta.
  desc 'Limpia las pláticas del probador que quedaron fuera de sus bandejas'
  task cleanup_legacy: :environment do
    own = Inbox.where(channel_type: 'Channel::Api',
                      channel_id: Channel::Api.where("additional_attributes ->> '#{AgentTester::Sandbox::MARK}' = 'true'").select(:id))
    scope = Conversation.where("additional_attributes ->> '#{AgentTester::Sandbox::MARK}' = 'true'").where.not(inbox_id: own.select(:id))
    scope = scope.where(account_id: ENV['ACCOUNT_ID']) if ENV['ACCOUNT_ID'].present?
    kept = scope.where(id: AgentTestLog.where.not(conversation_id: nil).select(:conversation_id)).count
    puts "Pláticas del probador fuera de sus bandejas: #{scope.count} (se quedan #{kept} que cita la bitácora)"
    scope.group(:account_id, :inbox_id).count.each { |(account, inbox), n| puts "  cuenta #{account} · bandeja #{inbox}: #{n}" }
    next if ENV['DRY_RUN'].present?

    AgentTester::CleanupJob.clean(scope, idle: 0.seconds, keep: 0.seconds)
    puts "Quedan: #{scope.count}"
  end
end
