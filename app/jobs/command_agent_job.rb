# frozen_string_literal: true
# proyecto@bot_comando

# ================================================================================
# proyecto@commands_agents [ARCHIVO NUEVO]
# ================================================================================
# Job: CommandAgentJob
# Descripcion: Procesa mensajes de agente que contienen comandos.
#              Busca la sesion activa de la conversacion y delega al Registry.
#              Si no hay sesion activa e inicia con '/', crea una nueva sesion.
#
# Flujo:
#   1. Carga el mensaje por ID
#   2. Busca sesion activa en la conversacion
#   3a. Con sesion activa -> continua el flujo del comando en curso
#   3b. Sin sesion + mensaje inicia con '/' -> Registry.handle_new_command
#   4. El Registry delega al Command correspondiente
#
# Fecha: 2026-02-19
# ================================================================================

class CommandAgentJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless message

    conversation = message.conversation
    content      = message.content.strip

    Rails.logger.info "[CommandAgentJob] Procesando mensaje #{message_id}: '#{content.truncate(60)}'"

    # Buscar sesion activa para esta conversacion
    session = CommandSession.active_for_conversation(conversation.id)

    if session&.still_active?
      # Continuar flujo existente
      Rails.logger.info "[CommandAgentJob] Sesion activa encontrada (#{session.command}/#{session.current_step})"
      CommandAgents::Registry.handle_step(session, message)
    elsif content.start_with?('/')
      # Iniciar nuevo comando
      Rails.logger.info "[CommandAgentJob] Iniciando nuevo comando: #{content.split.first}"
      CommandAgents::Registry.handle_new_command(message)
    else
      Rails.logger.debug "[CommandAgentJob] Sin sesion activa y sin '/' - ignorado"
    end
  rescue StandardError => e
    Rails.logger.error "[CommandAgentJob] Error procesando mensaje #{message_id}: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
  end
end
