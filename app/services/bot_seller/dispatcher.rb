# frozen_string_literal: true

# El armado del envio esta partido en helpers (endpoint_url / build_http / build_request)
# porque `dispatch` no pasaba Metrics/AbcSize y el hook de pre-commit rechaza el archivo.
# El comportamiento es el mismo que tenia en una sola pieza.
class BotSeller::Dispatcher
  def initialize(message)
    @message = message
  end

  def dispatch
    return unless self.class.configured?

    require 'net/http'
    require 'json'

    uri      = URI(endpoint_url)
    response = build_http(uri).request(build_request(uri))
    Rails.logger.info "[BotSeller] 📤 Evento enviado → respondió BotSeller (HTTP #{response.code})"
  rescue StandardError => e
    Rails.logger.warn "[BotSeller] ⚠️ No se pudo enviar evento: #{e.message}"
  end

  def self.configured?
    ENV.fetch('INTERNAL_WEBHOOK_URL', '').present?
  end

  private

  # El token del agente viaja en la query del endpoint, reemplazando el que traiga.
  def endpoint_url
    ENV.fetch('INTERNAL_WEBHOOK_URL', '').sub(/token=[^&]+/, "token=#{resolve_agent_token}")
  end

  def build_http(uri)
    http              = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = uri.scheme == 'https'
    http.open_timeout = 5
    http.read_timeout = 15
    http
  end

  def build_request(uri)
    request                 = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body            = build_payload.to_json
    request
  end

  # Este webhook NO pasa por Webhooks::Trigger -- se envia con Net::HTTP propio --, asi
  # que el instance_url que el trigger inyecta en todos los demas envios hay que ponerlo
  # aqui a mano. Sin esto, un receptor que atiende varias instancias no puede saber de
  # cual vino el mensaje saliente.
  def build_payload
    payload      = @message.webhook_data.merge(event: 'message_created')
    instance_url = Webhooks::Trigger.instance_url
    return payload if instance_url.blank?

    payload.merge(instance_url: instance_url)
  end

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
