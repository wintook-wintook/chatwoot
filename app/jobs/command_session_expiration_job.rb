# frozen_string_literal: true
# proyecto@bot_comando

# ================================================================================
# proyecto@commands_agents [ARCHIVO NUEVO]
# ================================================================================
# Job: CommandSessionExpirationJob
# Descripcion: Expira sesiones de comando que llevan mas de 30 minutos inactivas.
#              Notifica al agente-contacto en el widget para que pueda reiniciar.
# Frecuencia: Cada 5 minutos (via sidekiq-cron en schedule.yml)
# Fecha: 2026-02-20
# ================================================================================

class CommandSessionExpirationJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    expired_count = 0

    CommandSession.expired_pending.find_each do |session|
      notify_expiration(session)
      session.expire!
      expired_count += 1
      Rails.logger.info "[CommandSessionExpirationJob] Sesion ##{session.id} expirada " \
                        "(conv: #{session.conversation_id}, comando: #{session.command})"
    end

    Rails.logger.info "[CommandSessionExpirationJob] #{expired_count} sesion(es) expirada(s)" if expired_count > 0
  end

  private

  def notify_expiration(session)
    conversation = session.conversation
    return unless conversation

    hook = session.account.hooks.enabled.find_by(app_id: 'command_bot', inbox_id: session.inbox_id)
    agent_user = User.find_by(id: hook&.settings&.dig('agent_id')) || session.account.users.first
    return unless agent_user

    Messages::MessageBuilder.new(
      agent_user,
      conversation,
      {
        content:      "⏱️ Tu sesión de */#{session.command}* expiró por inactividad.\n\nEscribe */#{session.command}* para comenzar de nuevo.",
        private:      false,
        message_type: :outgoing
      }
    ).perform
  rescue StandardError => e
    Rails.logger.error "[CommandSessionExpirationJob] Error notificando sesion ##{session.id}: #{e.message}"
  end
end
