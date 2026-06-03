# frozen_string_literal: true

module BotSeller
  class SessionManager
    SESSION_TTL = 30 * 60  # 30 minutos en segundos
    KEY_PREFIX  = 'botseller:session:'

    # Comandos que inician un flujo interactivo (multi-paso) en BotSeller.
    # Todo comando que empiece con / excepto /salir abre sesión.
    def self.session_command?(text)
      return false if text.blank?

      text.strip.match?(/\A\//) && !text.strip.casecmp('/salir').zero?
    end

    def self.active?(conversation_id)
      with_redis { |r| r.exists(key(conversation_id)) }.to_i > 0
    end

    def self.start!(conversation_id, command)
      with_redis { |r| r.setex(key(conversation_id), SESSION_TTL, command.to_s.strip) }
    end

    def self.extend!(conversation_id)
      with_redis { |r| r.expire(key(conversation_id), SESSION_TTL) }
    end

    def self.close!(conversation_id)
      with_redis { |r| r.del(key(conversation_id)) }
    end

    def self.key(conversation_id)
      "#{KEY_PREFIX}#{conversation_id}"
    end

    def self.with_redis(&block)
      $alfred.with(&block)
    rescue StandardError => e
      Rails.logger.warn "[BotSeller::SessionManager] Redis error: #{e.message}"
      nil
    end
  end
end
