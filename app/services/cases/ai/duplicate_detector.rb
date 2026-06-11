# frozen_string_literal: true

# ================================================================================
# @tickets_cases 3D — Detección de incidentes repetidos → sugerir Problema
# ================================================================================
# Servicio: Cases::Ai::DuplicateDetector
#
# Busca incidentes similares al ticket dado por similitud semántica. Embebe el
# ticket objetivo + los incidentes candidatos en UNA sola llamada batch y calcula
# similitud coseno en Ruby (sin tabla de embeddings ni backfill). Devuelve los
# matches ordenados y si conviene sugerir crear un Problema. nil ante fallo.
# ================================================================================

class Cases::Ai::DuplicateDetector < Cases::Ai::BaseService
  CANDIDATE_LIMIT = 40
  SIMILARITY_THRESHOLD = 0.55
  MAX_MATCHES = 5
  SUGGEST_PROBLEM_AT = 2 # nº de matches fuertes para sugerir crear un Problema

  def detect(ticket)
    candidates = candidate_tickets(ticket)
    return { 'matches' => [], 'suggest_problem' => false } if candidates.empty?

    texts = [text_of(ticket)] + candidates.map { |c| text_of(c) }
    vectors = embed_batch(texts)
    return nil if vectors.blank? || vectors.size != texts.size

    target = vectors.first
    scored = candidates.each_with_index.map do |c, idx|
      { ticket: c, similarity: cosine(target, vectors[idx + 1]) }
    end

    matches = scored
              .select { |s| s[:similarity] >= SIMILARITY_THRESHOLD }
              .sort_by { |s| -s[:similarity] }
              .first(MAX_MATCHES)

    {
      'matches'         => matches.map { |m| match_json(m) },
      'suggest_problem' => matches.size >= SUGGEST_PROBLEM_AT
    }
  end

  private

  # Incidentes de la cuenta, no cancelados, distintos del ticket, recientes.
  def candidate_tickets(ticket)
    ticket.account.case_tickets
          .kind_incident
          .where.not(id: ticket.id)
          .where.not(status: %w[cancelled])
          .order(created_at: :desc)
          .limit(CANDIDATE_LIMIT)
          .to_a
  end

  def text_of(ticket)
    [ticket.title, ticket.description].compact.join("\n")[0, 2000]
  end

  def cosine(a, b)
    dot = 0.0
    na = 0.0
    nb = 0.0
    a.each_index do |i|
      dot += a[i] * b[i]
      na += a[i]**2
      nb += b[i]**2
    end
    return 0.0 if na.zero? || nb.zero?

    dot / (Math.sqrt(na) * Math.sqrt(nb))
  end

  def match_json(match)
    t = match[:ticket]
    {
      'id'          => t.id,
      'folio'       => t.folio,
      'title'       => t.title,
      'status'      => t.status,
      'similarity'  => match[:similarity].round(3)
    }
  end
end
