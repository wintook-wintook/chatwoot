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
    return unless authorized_agent?(message, hook)

    Rails.logger.info "[CommandAgentListener] Comando detectado '#{message.content.strip}' " \
                      "por agente #{message.sender_id} en conversación #{message.conversation_id}"

    CommandAgentJob.perform_later(message.id)
  end

  private

  # El mensaje debe ser incoming (escrito desde el widget) y cumplir una de:
  #   a) Empieza con '/' -> nuevo comando
  #   b) Hay sesion activa en esa conversacion -> respuesta al flujo en curso
  def command_message?(message)
    return false unless message.incoming?
    return false if message.content.blank?

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
