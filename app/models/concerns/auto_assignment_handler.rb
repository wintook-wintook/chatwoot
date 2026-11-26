module AutoAssignmentHandler
  extend ActiveSupport::Concern
  include Events::Types

  included do
    after_save :run_auto_assignment
  end

  private

  def run_auto_assignment
    # Round robin kicks in on conversation create & update
    # run it only when conversation status changes to open
    return unless conversation_status_changed_to_open?
    return unless should_run_auto_assignment?

    ::AutoAssignment::AgentAssignmentService.new(conversation: self, allowed_agent_ids: inbox.member_ids_with_assignment_capacity).perform
  end

  def should_run_auto_assignment?
    return false unless inbox.enable_auto_assignment?
    # Mientras la atiende un agente de IA (o la abre una campaña), no se le asigna a una persona por turno: se asigna
    # cuando la IA la entrega (Plan-Agente-IA-en-Conversaciones).
    return false if additional_attributes.to_h['ai_campaign'].present? || Conversations::AiAttendant.for(self).present?

    # run only if assignee is blank or doesn't have access to inbox
    assignee.blank? || inbox.members.exclude?(assignee)
  end
end
