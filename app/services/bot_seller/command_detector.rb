# frozen_string_literal: true

module BotSeller
  class CommandDetector
    PATTERNS = [
      /\A\//,           # /cotizar, /salir, /ver_comandos, /+prospecto
      /\A\?/,           # ?saldo, ?existencia, ?estatuspedido
      /\A=/,            # =clave exacta
      /\Areiniciar\z/i,
      /\Areset\z/i
    ].freeze

    def self.command?(text)
      return false if text.blank?

      PATTERNS.any? { |pattern| text.strip =~ pattern }
    end
  end
end
