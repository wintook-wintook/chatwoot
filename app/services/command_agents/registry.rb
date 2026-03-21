# frozen_string_literal: true
# proyecto@bot_comando

# ================================================================================
# proyecto@commands_agents [ARCHIVO NUEVO]
# ================================================================================
# Service: CommandAgents::Registry
# Descripcion: Registro central de comandos disponibles.
#              Resuelve el nombre del comando al handler correcto y lo ejecuta.
#
# Comandos registrados:
#   /sigue         -> Commands::Sigue
#   /siguecancelar -> Commands::Siguecancelar
#
# Uso:
#   Registry.handle_new_command(message)   # Inicia nuevo comando
#   Registry.handle_step(session, message) # Continua sesion existente
#
# Fecha: 2026-02-19
# ================================================================================

module CommandAgents
  class Registry
    # Mapa de nombre de comando -> clase handler
    COMMANDS = {
      'sigue'         => CommandAgents::Commands::Sigue,
      'siguecancelar' => CommandAgents::Commands::Siguecancelar
    }.freeze

    # Inicia un nuevo comando desde un mensaje que empieza con '/'
    # @param message [Message]
    def self.handle_new_command(message)
      command_name, *args = message.content.strip.split
      command_name = command_name.downcase.delete_prefix('/')

      handler_class = COMMANDS[command_name]

      unless handler_class
        reply_to(message, "Comando *#{command_name}* no reconocido.\n\nComandos disponibles: /#{COMMANDS.keys.join(', /')}")
        return
      end

      Rails.logger.info "[CommandAgents::Registry] Iniciando comando '#{command_name}'"
      handler_class.new(message, args).start
    end

    # Continua el flujo de una sesion activa con la respuesta del agente
    # @param session [CommandSession]
    # @param message [Message]
    def self.handle_step(session, message)
      handler_class = COMMANDS[session.command]

      unless handler_class
        Rails.logger.error "[CommandAgents::Registry] Comando '#{session.command}' no tiene handler"
        session.cancel!
        return
      end

      Rails.logger.info "[CommandAgents::Registry] Continuando '#{session.command}' en paso '#{session.current_step}'"
      handler_class.new(message, [], session).continue
    end

    # Envia un mensaje de respuesta al agente en la misma conversacion
    # @param message [Message] mensaje original del agente
    # @param text [String] texto de respuesta
    def self.reply_to(message, text)
      message.conversation.messages.create!(
        account:      message.account,
        inbox:        message.inbox,
        message_type: :activity,
        content:      text,
        private:      true
      )
    rescue StandardError => e
      Rails.logger.error "[CommandAgents::Registry] Error enviando respuesta: #{e.message}"
    end
  end
end
