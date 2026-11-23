# frozen_string_literal: true

# Motor 2.0 de Agentes a medida: los intentos de un agente 2.0 los escribe ese motor
# (Motor2::AttemptHook). Plan: docs/vault-tickets/implementacion/Plan-Motor-Agentes.md §11.11.
Rails.application.config.to_prepare do
  ContactTrackingJob.prepend(Motor2::AttemptHook) unless ContactTrackingJob <= Motor2::AttemptHook
  # Campaña con Vendedor IA: las conversaciones de listas frías no llenan la bandeja (Motor2::ListConversation).
  ContactTrackingJob.prepend(Motor2::ListConversationHook) unless ContactTrackingJob <= Motor2::ListConversationHook
  # Campaña con Vendedor IA: antes de cada toque, horario, topes, baja y si ya lo atiende una persona (SendGate).
  ContactTrackingJob.prepend(Motor2::CampaignSendHook) unless ContactTrackingJob <= Motor2::CampaignSendHook
end
