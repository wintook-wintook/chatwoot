# frozen_string_literal: true

# Probador de agentes — la basura de las pruebas (corre cada noche, config/schedule.yml):
#   - pláticas del probador que se quedaron abiertas (el chat de la pantalla no tiene «terminar»):
#     tras IDLE sin actividad se cierran igual que al terminar una corrida (Sandbox#finish);
#   - pláticas de más de KEEP: se borran con su contacto «Probador · …», salvo las que cita la
#     bitácora (agent_test_logs.conversation_id), que se quedan para «Seguir la plática».
# Solo recorre las bandejas marcadas del probador (índice por inbox_id). Las pláticas viejas que
# quedaron en bandejas reales se limpian una vez con `rake agent_tester:cleanup_legacy`.
class AgentTester::CleanupJob < ApplicationJob
  queue_as :scheduled_jobs

  IDLE = 1.day
  KEEP = 7.days

  def perform
    Inbox.where(channel_type: 'Channel::Api', channel_id: tester_channel_ids).find_each do |inbox|
      self.class.clean(Conversation.where(inbox_id: inbox.id))
    end
  end

  def self.clean(scope, idle: IDLE, keep: KEEP)
    scope.where(status: :open).where('last_activity_at < ?', idle.ago).find_each do |conversation|
      AgentTester::Sandbox.new(conversation.account).finish(conversation)
    end

    referenced = AgentTestLog.where.not(conversation_id: nil).select(:conversation_id)
    scope.where('conversations.last_activity_at < ?', keep.ago).where.not(id: referenced).find_each do |conversation|
      contact = conversation.contact
      # El seguimiento apunta a la plática (FK): va primero.
      ContactTracking.where(conversation_id: conversation.id).destroy_all
      conversation.destroy!
      # El contacto «Probador · …» es de esta sola plática; si por algo tiene más, se queda.
      contact.destroy! if contact&.conversations&.none?
    end
  end

  private

  def tester_channel_ids
    Channel::Api.where("additional_attributes ->> '#{AgentTester::Sandbox::MARK}' = 'true'").select(:id)
  end
end
