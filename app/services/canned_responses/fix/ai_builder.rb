# frozen_string_literal: true

# ================================================================================
# proyecto@arreglar_predefinidas F2 — LO COMÚN DE LOS ARREGLOS CON IA DE LA AUDITORÍA
# ================================================================================
# Redacción, unir, separar y resolver siguen el mismo camino que «pasa del tope»
# (Fix::Builder): la IA propone → candados (Fix::Checks, armados por Fix::Context) →
# una segunda vuelta con los problemas en frases si algo falla → se queda la mejor.
# Cada subclase pone su prompt (#system, #user), cómo leer la respuesta (#parse) y qué
# cuenta como problema para la segunda vuelta (#problems).
#
# `corpus` y `api_key` existen para el banco de pruebas (ver Fix::Checks).
# ================================================================================

class CannedResponses::Fix::AiBuilder
  MODEL = 'gpt-4o'

  attr_reader :error_code

  def self.error_code(error)
    texto = error.to_s
    return 'no_credits' if texto.match?(/insufficient_quota|credit_balance|billing/)
    return 'rate_limit' if texto.start_with?('HTTP 429')
    return 'too_long' if texto.include?('max_tokens')

    'ai_failed'
  end

  def initialize(context, api_key: nil, corpus: nil)
    @context = context
    @api_key = api_key || ContactTrackings::Assistant::OpenaiChat.new(account: context.account).api_key
    @corpus = corpus
  end

  # { proposal:, checks: } o nil (#error_code dice por qué)
  def call
    raise CannedResponses::Fix::Builder::NoKeyError, 'no_key' if @api_key.blank?

    propuesta = parse(ask(user))
    return failure if propuesta.nil?

    revisada = check(propuesta)
    problemas = problems(revisada)
    propuesta, revisada = second_round(propuesta, revisada, problemas) if problemas.any?
    finish(propuesta, revisada)
  end

  private

  # Para las subclases que necesitan un último paso (p. ej. partir por tamaño).
  def finish(propuesta, revisada) = { proposal: propuesta, checks: revisada }

  def check(propuesta)
    checks.call(propuesta['parts'], propuesta['questions'] || [], embeddings: embeddings?)
  end

  def embeddings? = true

  def problems(revisada) = CannedResponses::Fix::Checks.problems(revisada, 'split')

  def second_round(propuesta, revisada, problemas)
    mensaje = "#{user}\n\n## Tu propuesta anterior\n#{propuesta.slice('parts').to_json}\n\n" \
              "## Problemas que tienes que corregir\n#{problemas.map { |p| "- #{p}" }.join("\n")}\n\n" \
              'Devuelve la propuesta completa corregida, en el mismo JSON.'
    otra = parse(ask(mensaje))
    return [propuesta, revisada] if otra.nil?

    otra_revisada = check(otra)
    antes = [revisada['blocking'].size, problemas.size]
    despues = [otra_revisada['blocking'].size, problems(otra_revisada).size]
    (despues <=> antes) <= 0 ? [otra.merge('repaired' => true), otra_revisada] : [propuesta, revisada]
  end

  def ask(mensaje, max_tokens: 8000)
    @chat ||= ContactTrackings::Assistant::OpenaiChat.new(account: @context.account, api_key: @api_key)
    out = @chat.call([{ role: 'system', content: system }, { role: 'user', content: mensaje }],
                     max_tokens: max_tokens, temperature: 0.1, model: MODEL)
    @last_error = @chat.last_error
    out
  end

  def failure
    @error_code = self.class.error_code(@last_error)
    nil
  end

  def checks = @checks ||= @context.checks(api_key: @api_key, corpus: @corpus)

  def hard_data_list
    datos = CannedResponses::Fix::HardData.extract(@context.reference)
    prohibidos = (@context.resolution&.forbidden || []).filter_map { |i| i['key'] }.to_set
    datos.reject { |d| prohibidos.include?(d['key']) }.map { |d| "- #{d['text']}" }.join("\n").presence || '(ninguno)'
  end

  def response_block(response, label = nil)
    "#{"### #{label}\n" if label}Nombre: #{response.short_code}\nContenido:\n#{response.content}"
  end

  def text(value) = value.to_s.strip
end
