# frozen_string_literal: true

# ================================================================================
# proyecto@contact_tracking - COORDINADOR DE MENSAJES
# ================================================================================
# Servicio: MessageCoordinator
#
# Recibe un mensaje entrante con sus trackings activos y coordina quién responde:
#
#   1. Con trackings → llama al tracking_handler por cada uno, para al primer true
#   2. Sin trackings → intenta BotSeller si está configurado
#
# El tracking_handler (process_message_for_tracking) retorna:
#   true  → respondió, no procesar más
#   false → no respondió, continuar
# ================================================================================

class MessageCoordinator
  def initialize(message:, trackings:, tracking_handler:)
    @message          = message
    @trackings        = trackings
    @tracking_handler = tracking_handler
  end

  def route
    if @trackings.none?
      handle_no_trackings
      return
    end

    Rails.logger.info "[Coordinator] 📋 #{@trackings.size} tracking(s) activo(s) para el mensaje"

    @trackings.each do |tracking|
      replied = @tracking_handler.call(tracking, @message)
      if replied
        Rails.logger.info "[Coordinator] ✅ Tracking ##{tracking.id} respondió — fin"
        return
      end
    end

    Rails.logger.info '[Coordinator] ⚠️  Ningún tracking respondió'
  end

  private

  def handle_no_trackings
    Rails.logger.info '[Coordinator] ℹ️  Sin trackings activos para este mensaje'

    if BotSeller::Dispatcher.configured?
      Rails.logger.info '[Coordinator] 🤖 Sin tracking → derivando a BotSeller'
      BotSeller::Dispatcher.new(@message).dispatch
    end
  rescue StandardError => e
    Rails.logger.error "[Coordinator] ❌ Error en BotSeller fallback: #{e.message}"
  end
end
