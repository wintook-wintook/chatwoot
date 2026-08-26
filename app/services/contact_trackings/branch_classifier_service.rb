# frozen_string_literal: true

# ================================================================================
# proyecto@contact_tracking — CLASIFICADOR DE RAMA (@ruta)
# ================================================================================
# Decide a cuál de las ramas DECLARADAS por el agente pertenece el turno actual.
# No conoce ninguna rama de antemano: las opciones salen del RouteMap, así que sirve
# igual para tres ramas que para siete, con los nombres que se hayan elegido.
#
# Una sola llamada corta al LLM, con el modelo configurado en el inbox. Si algo falla
# (sin API key, timeout, respuesta rara) devuelve la rama por defecto declarada, o nil.
# Nunca levanta excepción: el turno debe poder seguir sin ruteo.
# ================================================================================

module ContactTrackings
  class BranchClassifierService
    MAX_HISTORY_CHARS = 600

    def initialize(tracking, message, route_map, recent_context: nil)
      @tracking  = tracking
      @message   = message
      @route_map = route_map
      @context   = recent_context.to_s
    end

    # Devuelve la Route elegida, o nil si no se pudo decidir y no hay rama por defecto.
    def classify
      return nil if @route_map.blank?
      return @route_map.routes.first if @route_map.routes.one?

      name = ask_llm
      route = @route_map[name]
      if route
        Rails.logger.info "[BranchClassifier] 🧭 Rama: #{route.name}"
        return route
      end

      fallback = @route_map.default
      Rails.logger.info "[BranchClassifier] ⚠️ Sin rama reconocida (#{name.inspect}) → " \
                        "#{fallback ? "por defecto: #{fallback.name}" : 'sin ruteo'}"
      fallback
    rescue StandardError => e
      Rails.logger.warn "[BranchClassifier] ⚠️ #{e.message} → rama por defecto"
      @route_map.default
    end

    private

    def ask_llm
      api_key = openai_api_key
      return nil if api_key.blank?

      body = post_json(api_key)
      raw  = JSON.parse(body).dig('choices', 0, 'message', 'content').to_s
      JSON.parse(raw)['rama'].to_s.strip.downcase.presence
    rescue StandardError => e
      Rails.logger.warn "[BranchClassifier] ⚠️ LLM: #{e.message}"
      nil
    end

    def post_json(api_key)
      require 'net/http'
      require 'json'

      uri               = URI('https://api.openai.com/v1/chat/completions')
      http              = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = true
      http.read_timeout = 10

      request                  = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{api_key}"
      request['Content-Type']  = 'application/json'
      request.body = {
        model: ContactTrackings::EngineConfig.model_for_tracking(@tracking, :router),
        messages: [{ role: 'user', content: prompt }],
        max_tokens: 60,
        temperature: 0.1,
        response_format: { type: 'json_object' }
      }.to_json

      http.request(request).body
    end

    def prompt
      <<~PROMPT.strip
        Clasificá el mensaje de un cliente en UNA de estas ramas de atención:
        #{@route_map.catalog.map { |c| "- #{c}" }.join("\n")}

        Reglas:
        - Elegí por el OBJETIVO del cliente, nunca por una palabra suelta.
        - Si quiere RESOLVER una falla, error o problema de algo que ya usa, es la rama
          técnica o de soporte, aunque mencione una factura, una cotización o un vendedor.
        - Si el mensaje continúa un tema que ya se venía tratando, conservá esa misma rama.
        - Si ninguna encaja con claridad, devolvé null.

        #{contexto}Mensaje actual del cliente:
        "#{@message.content.to_s.strip.truncate(300)}"

        Respondé SOLO un JSON: {"rama": "<uno de: #{@route_map.names.join(' | ')} | null>"}
      PROMPT
    end

    def contexto
      return '' if @context.blank?

      "Mensajes recientes de la conversación:\n#{@context.truncate(MAX_HISTORY_CHARS)}\n\n"
    end

    def openai_api_key
      @message.account.hooks.find_by(app_id: 'openai', status: 'enabled')
              &.settings&.dig('api_key').presence
    end
  end
end
