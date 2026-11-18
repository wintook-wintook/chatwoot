# frozen_string_literal: true

# ================================================================================
# proyecto@arreglar_predefinidas — ARMAR LA PROPUESTA
# ================================================================================
#   1. Limpieza sin IA (Fix::Cleanup). Si con eso ya cabe, la propuesta es «clean» y no
#      se llama a la IA.
#   2. La IA propone (Fix::Proposer) con los datos obligatorios y los prefijos de grupo.
#   3. Candados (Fix::Checks). Si algo bloquea, una parte pasa de TARGET_CHARS o se
#      perdieron frases, una segunda vuelta a la IA con los problemas en frases; se queda
#      la mejor de las dos.
#   4. Red sin IA (Fix::Rebalance) para lo que la IA no resolvió: tamaño, o condensar que
#      perdió contenido. `fallback` en la propuesta dice si se usó.
#
# Los datos que no se pueden perder se sacan del texto YA LIMPIO: un logo en base64 no
# tiene datos, y una liga HTML ya quedó como «texto (URL)».
# ================================================================================

class CannedResponses::Fix::Builder
  class NoKeyError < StandardError; end

  # corpus / api_key: para el banco de pruebas (ver Fix::Checks).
  def initialize(account, api_key: nil, corpus: nil)
    @account = account
    @api_key = api_key || ContactTrackings::Assistant::OpenaiChat.new(account: account).api_key
    @corpus = corpus
  end

  attr_reader :error_code

  # { proposal:, checks: } o nil (la IA no contestó; ver #error_code)
  def call(response)
    raise NoKeyError, 'no_key' if @api_key.blank?

    @response = response
    @cleaned = CannedResponses::Fix::Cleanup.call(response.content)
    @reference = CannedResponse.agent_text(response.short_code, @cleaned.content)
    @prefixes = CannedResponses::Fix::Groups.new(@account).required_prefixes(response.short_code)
    return clean_only if @reference.size <= CannedResponses::Fix::Proposer::TARGET_CHARS && @cleaned.removed.any?

    with_ai
  end

  private

  def cleanup_info
    { 'removed' => @cleaned.removed, 'chars_before' => @response.agent_chars, 'chars_after' => @reference.size }
  end

  def clean_only
    proposal = { 'action' => 'clean', 'shape' => nil, 'subject' => nil, 'reason' => nil, 'cleanup' => cleanup_info,
                 'parts' => [{ 'short_code' => @response.short_code, 'content' => @cleaned.content }], 'questions' => [] }
    { proposal: proposal, checks: checks.call(proposal['parts'], [], embeddings: false) }
  end

  def with_ai
    entrada = { name: @response.short_code, content: @cleaned.content,
                hard_data: CannedResponses::Fix::HardData.extract(@reference), prefixes: @prefixes }
    propuesta = normalize(proposer.call(**entrada))
    return fail_with_ai_error if propuesta.nil?

    revisada = checks.call(propuesta['parts'], propuesta['questions'])
    problemas = CannedResponses::Fix::Checks.problems(revisada, propuesta['action'])
    propuesta, revisada = second_round(entrada, propuesta, revisada, problemas) if problemas.any?
    propuesta, revisada = safety_net(propuesta, revisada)
    { proposal: propuesta.merge('cleanup' => cleanup_info), checks: revisada }
  end

  # La red sin IA (Fix::Rebalance), si después de dos vueltas:
  #   · condensar perdió más de lo tolerable → se descarta lo condensado y la original
  #     (limpia) se parte por bloques, sin reescribir nada;
  #   · alguna parte pasa de TARGET_CHARS → esa parte se parte por bloques.
  def safety_net(propuesta, revisada)
    objetivo = CannedResponses::Fix::Proposer::TARGET_CHARS
    if propuesta['action'] == 'condense' && condense_lost_too_much?(revisada)
      partes = CannedResponses::Fix::Rebalance.chunks(@response.short_code, @cleaned.content, objetivo)
      nueva = with_subject(propuesta.merge('action' => partes.size > 1 ? 'split' : 'clean', 'parts' => partes,
                                           'questions' => [], 'fallback' => 'mechanical'))
      return [nueva, checks.call(nueva['parts'], [])]
    end
    return [propuesta, revisada] if revisada.dig('size', 'parts').all? { |p| p['chars'] <= objetivo }

    partes, mapa = CannedResponses::Fix::Rebalance.call(propuesta['parts'], objetivo)
    preguntas = propuesta['questions'].map { |q| q.merge('part' => mapa[q['part']]) }
    accion = propuesta['action'] == 'condense' && partes.size > 1 ? 'split' : propuesta['action']
    nueva = with_subject(propuesta.merge('action' => accion, 'parts' => partes, 'questions' => preguntas,
                                         'fallback' => 'rebalanced'))
    [nueva, checks.call(partes, preguntas)]
  end

  # Al dividir, cada parte tiene que decir de quién habla aunque se lea sola: el prompt lo
  # pedía y no se comprobaba. 17/11/2026, cuenta 1: «Maestría en Administración de
  # Instituciones de Salud — Prácticas, titulación y costos» empezaba con «SERVICIO
  # SOCIAL…» y su texto nunca nombraba la maestría; junto a la de Negocios, con la misma
  # plantilla, la auditoría tomó sus precios como contradicción. Si la parte no nombra al
  # sujeto al principio, se le antepone en un renglón (no se reescribe nada).
  SUBJECT_WINDOW = 200

  def with_subject(propuesta)
    sujeto = propuesta['subject'].to_s.strip
    return propuesta if sujeto.empty? || propuesta['parts'].size < 2

    partes = propuesta['parts'].map do |p|
      inicio = ActiveSupport::Inflector.transliterate(p['content'].to_s.first(SUBJECT_WINDOW)).downcase
      next p if inicio.include?(ActiveSupport::Inflector.transliterate(sujeto).downcase)

      p.merge('content' => "#{sujeto}\n\n#{p['content']}")
    end
    propuesta.merge('parts' => partes)
  end

  def condense_lost_too_much?(revisada)
    cobertura = revisada['coverage'] || {}
    cobertura['dropped_count'].to_i > cobertura['lines'].to_i * CannedResponses::Fix::Checks::COVERAGE_CONDENSE_LOSS
  end

  # Se queda con la segunda solo si bloquea menos (o igual, con menos problemas).
  def second_round(entrada, propuesta, revisada, problemas)
    otra = normalize(proposer.repair(**entrada, previous: propuesta.slice('action', 'parts'), problems: problemas))
    return [propuesta, revisada] if otra.nil?

    otra_revisada = checks.call(otra['parts'], otra['questions'])
    antes = [revisada['blocking'].size, problemas.size]
    despues = [otra_revisada['blocking'].size, CannedResponses::Fix::Checks.problems(otra_revisada, otra['action']).size]
    (despues <=> antes) <= 0 ? [otra.merge('repaired' => true), otra_revisada] : [propuesta, revisada]
  end

  # condense (y mark_prompt en una sola parte): con el nombre de la original. Si la IA dijo
  # condense pero entregó varias, en realidad dividió; mark_prompt sí puede ir en varias
  # (instrucciones que ni condensadas caben: SITEXPRESS, cuenta 45, 4,001 → 3,947).
  def normalize(propuesta)
    return nil if propuesta.nil?

    propuesta = with_subject(propuesta)

    varias = propuesta['parts'].size > 1
    return propuesta.merge('action' => 'split') if varias && propuesta['action'] == 'condense'

    if %w[condense mark_prompt].include?(propuesta['action']) && !varias
      propuesta['parts'] = [propuesta['parts'].first.merge('short_code' => @response.short_code)]
    end
    propuesta
  end

  def fail_with_ai_error
    @error_code = ai_error_code(proposer.last_error)
    nil
  end

  def ai_error_code(error)
    texto = error.to_s
    return 'no_credits' if texto.match?(/insufficient_quota|credit_balance|billing/)
    return 'rate_limit' if texto.start_with?('HTTP 429')
    return 'too_long' if texto.include?('max_tokens')

    'ai_failed'
  end

  def proposer = @proposer ||= CannedResponses::Fix::Proposer.new(@account, api_key: @api_key)

  def checks
    @checks ||= CannedResponses::Fix::Checks.new(@account, original: @response, reference_text: @reference,
                                                           prefixes: @prefixes, api_key: @api_key, corpus: @corpus)
  end
end
