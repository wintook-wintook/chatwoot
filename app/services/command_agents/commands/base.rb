# frozen_string_literal: true
# proyecto@bot_comando

# ================================================================================
# proyecto@commands_agents [ARCHIVO NUEVO]
# ================================================================================
# Service: CommandAgents::Commands::Base
# Descripcion: Clase base para todos los comandos del bot de agentes.
#              Provee metodos comunes: responder, crear sesion, avanzar paso.
#
# Subclases deben implementar:
#   - COMMAND_NAME  (string)
#   - STEPS         (array de simbolos)
#   - start         (iniciar flujo)
#   - continue      (procesar respuesta del agente)
#
# Fecha: 2026-02-19
# ================================================================================

module CommandAgents
  module Commands
    class Base
      # @param message [Message] mensaje actual del agente
      # @param args [Array<String>] argumentos del comando (palabras tras el nombre)
      # @param session [CommandSession, nil] sesion existente (nil si es comando nuevo)
      def initialize(message, args = [], session = nil)
        @message      = message
        @args         = args
        @session      = session
        @conversation = message.conversation
        @account      = message.account
        @inbox        = message.inbox
        @agent        = message.sender
      end

      # Inicia el flujo del comando (debe ser implementado por subclase)
      def start
        raise NotImplementedError, "#{self.class}#start no implementado"
      end

      # Procesa la respuesta del agente y avanza el flujo (debe ser implementado por subclase)
      def continue
        raise NotImplementedError, "#{self.class}#continue no implementado"
      end

      protected

      # Envia mensaje outgoing visible en el widget al agente-contacto
      # Firmado por el usuario autorizado del hook (o primer usuario de la cuenta)
      # @param text [String]
      def reply(text)
        Messages::MessageBuilder.new(
          authorized_user,
          @conversation,
          {
            content:      text,
            private:      false,
            message_type: :outgoing
          }
        ).perform
      rescue StandardError => e
        Rails.logger.error "[Commands::Base] Error al responder: #{e.message}"
      end

      # Crea una nueva sesion activa para el comando.
      # Si ya existe una sesion activa en esta conversacion, la cancela primero.
      # @param first_step [String] nombre del primer paso
      # @param initial_data [Hash] datos iniciales opcionales
      # @return [CommandSession]
      def create_session(first_step, initial_data = {})
        # proyecto@commands_agents: cancelar sesion previa para evitar UniqueViolation
        existing = CommandSession.active_for_conversation(@conversation.id)
        existing&.cancel!

        @session = CommandSession.create!(
          account:        @account,
          user:           authorized_user,
          contact:        @conversation.contact,
          conversation:   @conversation,
          inbox:          @inbox,
          command:        self.class::COMMAND_NAME,
          current_step:   first_step,
          collected_data: initial_data
        )
        @session
      end

      # Devuelve el usuario autorizado segun el hook command_bot del inbox
      # Fallback al primer usuario de la cuenta si no se encuentra
      def authorized_user
        @authorized_user ||= begin
          hook = @account.hooks.enabled.find_by(app_id: 'command_bot', inbox_id: @inbox.id)
          User.find_by(id: hook&.settings&.dig('agent_id')) || @account.users.first
        end
      end

      # Avanza al siguiente paso de la sesion
      # @param step_name [String]
      def advance_to(step_name)
        @session.advance_to!(step_name)
      end

      # Guarda un dato recolectado en la sesion
      # @param key [Symbol, String]
      # @param value [Object]
      def save_data(key, value)
        @session.set_data(key, value)
      end

      # Obtiene un dato recolectado de la sesion
      # @param key [Symbol, String]
      def get_data(key)
        @session.get_data(key)
      end

      # Cancela la sesion activa con mensaje al agente
      # @param reason [String] razon de cancelacion
      def cancel_session(reason = 'Comando cancelado.')
        @session&.cancel!
        reply("❌ #{reason}")
      end

      # Detecta si el agente quiere cancelar
      # @param text [String]
      def cancel_requested?(text)
        %w[/salirsigue /salir /exit].include?(text.downcase.strip)
      end

      # Texto del mensaje actual del agente (limpio)
      def input
        @message.content.strip
      end
    end
  end
end
