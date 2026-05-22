# frozen_string_literal: true

module BotSeller
  class Dispatcher
    def initialize(message)
      @message = message
    end

    def dispatch
      base_url = ENV.fetch('INTERNAL_WEBHOOK_URL', '')
      return if base_url.blank?

      require 'net/http'
      require 'json'

      token = resolve_agent_token
      url   = base_url.sub(/token=[^&]+/, "token=#{token}")

      uri               = URI(url)
      http              = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = uri.scheme == 'https'
      http.open_timeout = 5
      http.read_timeout = 15

      payload                 = @message.webhook_data.merge(event: 'message_created')
      request                 = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body            = payload.to_json

      response = http.request(request)
      Rails.logger.info "[BotSeller] 📤 Evento enviado → respondió BotSeller (HTTP #{response.code})"
    rescue StandardError => e
      Rails.logger.warn "[BotSeller] ⚠️ No se pudo enviar evento: #{e.message}"
    end

    def self.configured?
      ENV.fetch('INTERNAL_WEBHOOK_URL', '').present?
    end

    private

    def resolve_agent_token
      assignee = @message.conversation.assignee

      if assignee&.access_token&.token.present?
        Rails.logger.info "[BotSeller] 🔑 Token: #{assignee.name} (agente asignado)"
        return assignee.access_token.token
      end

      fallback = User.joins(:access_token, :account_users)
                     .where(account_users: { account_id: @message.account_id })
                     .order(:created_at).first
      Rails.logger.info "[BotSeller] 🔑 Token: #{fallback&.name} (fallback)"
      fallback&.access_token&.token || ''
    end
  end
end
