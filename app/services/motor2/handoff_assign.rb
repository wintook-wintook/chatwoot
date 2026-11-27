# frozen_string_literal: true

# Motor 2.0 — al entregarle la conversación a una persona: el responsable y el equipo del destino. Si el destino es solo
# un equipo y la conversación no tiene responsable (las de campaña nacen sin él: Plan-Agente-IA-en-Conversaciones), queda
# el dueño de la campaña; y se quita la marca «ai_campaign» para que la asignación automática vuelva a funcionar.
module Motor2::HandoffAssign
  module_function

  def call(conversation, target, tracking: nil)
    attrs = { assignee_id: assignee_for(conversation, target, tracking), team_id: team_for(conversation, target) }
    extra = conversation.additional_attributes.to_h
    attrs[:additional_attributes] = extra.except('ai_campaign') if extra.key?('ai_campaign')
    conversation.update!(attrs.compact) if attrs.compact.any?
  end

  def assignee_for(conversation, target, tracking)
    user = conversation.account.users.where(id: target[:user_id]).pick(:id) if target[:user_id].present?
    user || (tracking&.tracking_campaign&.user_id if conversation.assignee_id.blank?)
  end

  def team_for(conversation, target)
    target[:team_id].present? ? conversation.account.teams.where(id: target[:team_id]).pick(:id) : nil
  end
end
