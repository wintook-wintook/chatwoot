# frozen_string_literal: true

# ================================================================================
# proyecto@auditoria_predefinidas — LOS PARES QUE VALE LA PENA COMPARAR
# ================================================================================
# Con los vectores que ya existen (knowledge_items, uno por predefinida): para cada
# predefinida, sus NEIGHBORS vecinas más parecidas con similitud ≥ MIN_SIMILARITY. Sin
# llamadas a OpenAI.
#
# Por qué vecinas y no todas contra todas: dos predefinidas solo se duplican o se
# contradicen si hablan de lo mismo, y las que hablan de lo mismo son vecinas. Comparar
# todas sería n² llamadas a la IA para encontrar lo mismo.
#
# La similitud sola NO dice «duplicada»: medido en la cuenta 1 (17/11/2026), las fichas de
# «Maestría en Educación» y «Maestría en Administración de Negocios» dan 0.874 y
# «Licenciatura en Derecho» vs «Relaciones Internacionales» 0.860 — misma estructura,
# distinto tema. Por eso solo desde DUPLICATE_SIMILARITY se da por duplicada sin
# preguntar; el resto lo decide la IA (CannedResponses::Audit::Reviewer).
#
# Devuelve [[id_menor, id_mayor, similitud], …] de la más parecida a la menos.
# ================================================================================

class CannedResponses::Audit::Neighbors
  NEIGHBORS = 3
  MIN_SIMILARITY = 0.72
  DUPLICATE_SIMILARITY = 0.95

  def initialize(account)
    @account = account
  end

  # Todas las de la cuenta.
  def all
    pairs(nil)
  end

  # Solo las vecinas de una (la que se acaba de guardar).
  def of(canned_response_id)
    pairs(canned_response_id)
  end

  private

  def pairs(only_id)
    rows = ActiveRecord::Base.connection.select_rows(ActiveRecord::Base.sanitize_sql_array([sql(only_id), params(only_id)]))
    existing = @account.canned_responses.pluck(:id).to_set
    best = {}
    rows.each do |a, b, sim|
      a = a.to_i
      b = b.to_i
      next unless existing.include?(a) && existing.include?(b)

      key = [a, b].minmax
      best[key] = sim.to_f if best[key].nil? || sim.to_f > best[key]
    end
    best.map { |(a, b), sim| [a, b, sim] }.sort_by { |_, _, sim| -sim }
  end

  def params(only_id)
    { account_id: @account.id, k: NEIGHBORS, min: MIN_SIMILARITY, only_id: only_id }
  end

  def sql(only_id)
    filtro = only_id ? 'AND a.source_id = :only_id' : ''
    <<~SQL.squish
      SELECT a.source_id, n.source_id, n.sim
      FROM knowledge_items a
      CROSS JOIN LATERAL (
        SELECT b.source_id, 1 - (a.embedding <=> b.embedding) AS sim
        FROM knowledge_items b
        WHERE b.account_id = a.account_id AND b.source_type = 'canned_response'
          AND b.source_id <> a.source_id AND b.embedding IS NOT NULL
        ORDER BY a.embedding <=> b.embedding
        LIMIT :k
      ) n
      WHERE a.account_id = :account_id AND a.source_type = 'canned_response'
        AND a.embedding IS NOT NULL AND n.sim >= :min #{filtro}
    SQL
  end
end
