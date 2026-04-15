# frozen_string_literal: true
# proyecto@bot_comando

# ================================================================================
# proyecto@commands_agents [ARCHIVO NUEVO]
# ================================================================================
# Listener: CommandAgentListener
# Descripcion: Detecta mensajes entrantes del agente-contacto que contienen
#              comandos (inician con /) y encola CommandAgentJob.
#
# Flujo de deteccion:
#   1. Mensaje creado -> message_created
#   2. Verifica que sea incoming (escrito desde el widget por el agente-contacto)
#   3. Verifica que el contenido inicie con '/'
#   4. Busca hook command_bot habilitado para el inbox
#   5. Verifica que el telefono del contacto coincida con agent_phone del hook
#   6. Encola CommandAgentJob
#
# Canales soportados: Website (desarrollo), WhatsApp
# Fecha: 2026-02-18 | Corregido: 2026-02-19
# ================================================================================

class CommandAgentListener < BaseListener
  include Singleton

  def message_created(event)
    message, _account = extract_message_and_account(event)

    return unless command_message?(message)

    hook = find_command_bot_hook(message)
    return unless hook

    # proyecto@commands_agents: mensajes desde el tab Bots del dashboard ya son de un usuario
    # autenticado — omitir la verificación de teléfono
    unless bot_command_from_dashboard?(message)
      return unless authorized_agent?(message, hook)
    end

    Rails.logger.info "[CommandAgentListener] Comando detectado '#{message.content.strip}' " \
                      "por agente #{message.sender_id} en conversación #{message.conversation_id}"

    CommandAgentJob.perform_later(message.id)
  end

  private

  # El mensaje debe ser incoming (escrito desde el widget) o saliente privado
  # (enviado desde el tab "Bots" del dashboard), y cumplir una de:
  #   a) Empieza con '/' -> nuevo comando
  #   b) Hay sesion activa en esa conversacion -> respuesta al flujo en curso
  def command_message?(message)
    return true if bot_command_from_dashboard?(message)
    return false unless message.incoming?
    return false if message.content.blank?

    message.content.strip.start_with?('/') ||
      CommandSession.active_for_conversation(message.conversation_id).present?
  end

  # Detecta mensajes enviados desde el tab Bots del dashboard:
  # outgoing + privado + sin marca bot_reply (los mensajes generados por el bot
  # tienen content_attributes['bot_reply'] = true)
  def bot_command_from_dashboard?(message)
    return false if message.content.blank?
    return false unless message.outgoing? && message.private?
    return false if message.content_attributes&.dig('bot_reply')  # excluye respuestas del bot

    message.content.strip.start_with?('/') ||
      CommandSession.active_for_conversation(message.conversation_id).present?
  end

  # Busca hook command_bot habilitado para el inbox del mensaje
  def find_command_bot_hook(message)
    message.account.hooks
           .enabled
           .where(app_id: 'command_bot', inbox_id: message.inbox_id)
           .first
  end

  # Verifica que el telefono del contacto coincida con agent_phone del hook
  # Compara los ultimos 10 digitos para flexibilidad con codigos de pais
  def authorized_agent?(message, hook)
    contact_phone    = message.sender&.phone_number.to_s
    authorized_phone = hook.settings['agent_phone'].to_s

    unless phones_match?(contact_phone, authorized_phone)
      Rails.logger.debug "[CommandAgentListener] Telefono '#{contact_phone}' no autorizado " \
                         "(autorizado: '#{authorized_phone}') en inbox #{message.inbox_id}"
      return false
    end

    true
  end

  # Compara ultimos 10 digitos para tolerar diferencias en codigo de pais
  def phones_match?(phone1, phone2)
    digits1 = phone1.gsub(/\D/, '').last(10)
    digits2 = phone2.gsub(/\D/, '').last(10)
    digits1.present? && digits1 == digits2
  end
end
