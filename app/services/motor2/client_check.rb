# frozen_string_literal: true

# Motor 2.0 — ¿ya es cliente? Su organización está en etapa Cliente, o ya tiene una
# oportunidad ganada o un caso de servicio (soporte, orden de trabajo, proyecto). Viene de
# ReadyAgents::ClientCheck (agentes listos de antes).
module Motor2::ClientCheck
  module_function

  def client?(contact)
    return false unless contact
    return true if contact.organization&.customer?

    tickets = CaseTicket.where(account_id: contact.account_id, contact_id: contact.id)
    tickets.exists?(outcome: CaseTicket.outcomes[:won]) ||
      tickets.joins(:case_type).where.not(case_types: { case_class: CaseType.case_classes[:commercial] }).exists?
  end
end
