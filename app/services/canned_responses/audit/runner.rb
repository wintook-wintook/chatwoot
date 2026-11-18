# frozen_string_literal: true

# ================================================================================
# proyecto@auditoria_predefinidas — CORRER LA AUDITORÍA
# ================================================================================
#   all          toda la cuenta (botón «Auditar», CannedResponses::AuditJob)
#   one(r)       una predefinida contra sus vecinas, al guardarla (AuditOneJob)
#
# Pasos:
#   1. Pares vecinos con los vectores (CannedResponses::Audit::Neighbors), sin IA.
#   2. Cada par a la IA: ¿duplicada, se solapa, distinta? ¿se contradicen? Desde
#      Neighbors::DUPLICATE_SIMILARITY es duplicada aunque la IA falle.
#   3. Redacción de cada predefinida, en lotes (Reviewer::WRITING_BATCH).
#   4. Se reemplazan los hallazgos abiertos de lo que SÍ se revisó, y los de pares que
#      ya no son vecinos. Lo que no se pudo revisar (la llamada falló) conserva lo que
#      tenía: una corrida sin créditos no puede borrar lo que encontró la anterior.
#      Los descartados se respetan: si sale el mismo hallazgo con el mismo texto
#      (digest), no se vuelve a abrir.
#
# Las llamadas a la IA van en THREADS hilos que no tocan la base (la clave se lee antes);
# lo que se guarda, en el hilo principal y en una transacción. Si OpenAI dice que no hay
# créditos (17/11/2026, cuenta 1: 33 de 40 llamadas con 429 insufficient_quota) se deja de
# llamar: las que faltan fallarían igual.
# ================================================================================

class CannedResponses::Audit::Runner
  class NoKeyError < StandardError; end

  THREADS = 4
  # Tope de pares por corrida: la cuenta más grande de dev tiene 62 predefinidas y da
  # ~40 pares; esto solo evita que una cuenta enorme se vuelva cientos de llamadas.
  MAX_PAIRS = 150

  def initialize(account)
    @account = account
    @api_key = ContactTrackings::Assistant::OpenaiChat.new(account: account).api_key
    @calls = Concurrent::AtomicFixnum.new(0)
    @failed = Concurrent::AtomicFixnum.new(0)
    @stop = Concurrent::AtomicBoolean.new(false)
    @errors = Concurrent::Array.new
    # Cargada aquí y no en los hilos (el autoload desde un hilo hijo espera al principal).
    @reviewer_class = CannedResponses::Audit::Reviewer
  end

  def all
    ensure_key!
    responses = @account.canned_responses.to_a
    pairs = CannedResponses::Audit::Neighbors.new(@account).all.first(MAX_PAIRS)
    run(responses, pairs, scope: @account.canned_response_findings)
  end

  def one(response)
    ensure_key!
    pairs = CannedResponses::Audit::Neighbors.new(@account).of(response.id)
    run([response], pairs, scope: @account.canned_response_findings.involving(response.id))
  end

  private

  def ensure_key!
    raise NoKeyError, 'no_key' if @api_key.blank?
  end

  def run(responses, pairs, scope:)
    by_id = @account.canned_responses.where(id: (responses.map(&:id) + pairs.flat_map { |a, b, _| [a, b] }).uniq).index_by(&:id)
    @candidates = pairs.to_set { |a, b, _| [a, b] }
    @reviewed_pairs = Set.new
    @reviewed_ids = Set.new
    @siblings = sibling_pairs
    found = pair_findings(pairs, by_id) + writing_findings(responses)
    saved = save(found, scope)
    { 'responses' => responses.size, 'pairs' => pairs.size, 'ai_calls' => @calls.value,
      'failed_calls' => @failed.value, 'error' => @errors.tally.max_by { |_, n| n }&.first,
      'found' => saved.group_by(&:kind).transform_values(&:size) }.compact
  end

  # ── pares ───────────────────────────────────────────────────────────────────
  def pair_findings(pairs, by_id)
    trabajos = pairs.filter_map do |a_id, b_id, sim|
      a = by_id[a_id]
      b = by_id[b_id]
      [a, b, sim] if a && b
    end
    resultados = in_threads(trabajos) { |a, b, _| reviewer.pair(a, b) }
    trabajos.zip(resultados).flat_map do |(a, b, sim), res|
      @reviewed_pairs << [a.id, b.id] if res
      findings_for_pair(a, b, sim, res)
    end
  end

  def findings_for_pair(first, second, sim, res)
    base = { canned_response_id: first.id, other_canned_response_id: second.id, similarity: sim,
             digest: CannedResponseFinding.digest_for(first, second) }
    detalle = { 'reason' => res&.dig('reason'), 'suggestion' => res&.dig('suggestion') }.compact_blank
    out = []
    # ≥ DUPLICATE_SIMILARITY es duplicada sin preguntar… salvo que la IA diga que son de
    # sujetos distintos (dos fichas de la misma plantilla se parecen 0.95 o más).
    casi_igual = sim >= CannedResponses::Audit::Neighbors::DUPLICATE_SIMILARITY && res&.dig('same_subject') != false
    if casi_igual || res&.dig('relation') == 'duplicate'
      out << base.merge(kind: 'duplicate', severity: casi_igual && res&.dig('relation') != 'distinct' ? 'high' : 'medium',
                        details: detalle)
    elsif res&.dig('relation') == 'overlap' && @siblings.exclude?([first.id, second.id])
      out << base.merge(kind: 'overlap', severity: 'low', details: detalle)
    end
    if res && res['contradictions'].present?
      out << base.merge(kind: 'contradiction', severity: 'high', details: { 'contradictions' => res['contradictions'] })
    end
    out
  end

  # Partes de una misma división aceptada («pasa del tope») o de una unión que se partió:
  # se separaron a propósito y comparten el sujeto, así que siempre se van a parecer. Entre
  # ellas no se marca «se solapan» (ni se sugiere unirlas: volverían a pasar del tope); un
  # duplicado o una contradicción sí, porque sería un error de la división.
  def sibling_pairs
    grupos = @account.canned_response_fixes.where(status: 'applied', kind: %w[oversize merge]).pluck(:result).map do |r|
      Array(r['created_ids']) + Array(r['updated_ids'])
    end
    grupos.flat_map { |ids| ids.sort.combination(2).to_a }.to_set
  end

  # ── redacción ───────────────────────────────────────────────────────────────
  def writing_findings(responses)
    lotes = responses.each_slice(CannedResponses::Audit::Reviewer::WRITING_BATCH).to_a
    resultados = in_threads(lotes) { |lote| reviewer.writing(lote) }
    by_id = responses.index_by(&:id)
    lotes.zip(resultados).flat_map do |lote, res|
      next [] unless res

      @reviewed_ids.merge(lote.map(&:id))
      res.filter_map do |id, issues|
        next if issues.blank?

        { canned_response_id: id, other_canned_response_id: nil, kind: 'writing', severity: writing_severity(issues),
          similarity: nil, digest: CannedResponseFinding.digest_for(by_id[id]), details: { 'issues' => issues } }
      end
    end
  end

  def writing_severity(issues)
    tipos = issues.pluck('type')
    return 'high' if tipos.include?('incompleta')
    return 'medium' if tipos.intersect?(%w[ortografia confusa numeracion])

    'low'
  end

  # ── guardar ─────────────────────────────────────────────────────────────────
  def save(found, scope)
    descartados = @account.canned_response_findings.dismissed
                          .pluck(:kind, :canned_response_id, :other_canned_response_id, :digest).to_set
    CannedResponseFinding.transaction do
      scope.unresolved.select { |f| replaceable?(f) }.each(&:delete)
      found.reject { |f| descartados.include?([f[:kind], f[:canned_response_id], f[:other_canned_response_id], f[:digest]]) }
           .map { |f| @account.canned_response_findings.create!(f) }
    end
  end

  # Se revisó de nuevo, o el par ya no es vecino (la duplicada o la contradicción, si
  # sigue, saldría en los candidatos).
  def replaceable?(finding)
    return @reviewed_ids.include?(finding.canned_response_id) if finding.kind == 'writing'

    par = [finding.canned_response_id, finding.other_canned_response_id]
    @reviewed_pairs.include?(par) || @candidates.exclude?(par)
  end

  # ── hilos ───────────────────────────────────────────────────────────────────
  # Un Reviewer por hilo (guarda estado de la última llamada).
  def reviewer
    Thread.current[:canned_audit_reviewer] ||= @reviewer_class.new(@account, api_key: @api_key)
  end

  # Mismo orden que `items`; nil donde la llamada falló o no se hizo.
  def in_threads(items, &)
    cola = Queue.new
    items.each_with_index { |item, i| cola << [item, i] }
    resultados = Array.new(items.size)
    hilos = Array.new([THREADS, items.size].min) { Thread.new { work(cola, resultados, &) } }
    ActiveSupport::Dependencies.interlock.permit_concurrent_loads { hilos.each(&:join) }
    resultados
  end

  def work(cola, resultados)
    loop do
      item, i = cola.pop(true)
      next @failed.increment if @stop.true?

      @calls.increment
      resultados[i] = yield(item)
      note_failure if resultados[i].nil?
    rescue ThreadError
      break
    rescue StandardError => e
      Rails.logger.error("[AuditoríaPredefinidas] #{e.class}: #{e.message}")
      @failed.increment
    end
  ensure
    Thread.current[:canned_audit_reviewer] = nil
  end

  def note_failure
    @failed.increment
    codigo = reviewer.last_error_code
    @errors << codigo if codigo
    @stop.make_true if codigo == 'no_credits'
  end
end
