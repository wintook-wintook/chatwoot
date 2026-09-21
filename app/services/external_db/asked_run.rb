# frozen_string_literal: true

# ================================================================================
# proyecto@erp_productos — CORRER UNA CONSULTA CON LOS VALORES YA LLENOS
# ================================================================================
# Plan: docs/erp_productos_plan.md (§3.2, §7.2). Lo usan el motor (AskedConsulta) y la
# prueba de la Consola ERP ("Probar como el agente"), así las dos dan lo mismo:
#
#   1. corre con el QueryRunner (solo SELECT, binds, tope) y recorta a `max`
#      (DEFAULT_MAX por defecto, tope MAX_ROWS);
#   2. si el texto tenía varias palabras y no hubo resultados, busca con cada palabra por
#      separado, ordena por la palabra más específica (1 / cuántos productos la tienen) y
#      lo marca PARCIAL. Medido: el catálogo dice "AIERE ACONDICIONADO TOSHIBA" y
#      "aire acondicionado toshiba" no encontraba nada; en el orden de las palabras, los
#      de "aire" llenaban los 5 lugares y el único Toshiba quedaba fuera.
#
# Devuelve { query:, columns:, rows:, partial: }. Los errores del QueryRunner suben.
# ================================================================================
class ExternalDb::AskedRun
  DEFAULT_MAX = 5
  MAX_ROWS = 10

  def initialize(query, params)
    @query = query
    @params = params.to_h.transform_keys(&:to_s)
  end

  def call
    result = ExternalDb::QueryRunner.new(@query, @params).perform
    Rails.logger.info "[ExternalDb::AskedRun] #{@query.name} #{@params.inspect} → #{result.row_count} fila(s)"
    return partial if result.rows.empty? && words.size > 1

    { query: @query, columns: result.columns, rows: result.rows.first(limit), partial: false }
  end

  private

  def partial
    results = words.map { |word| ExternalDb::QueryRunner.new(@query, @params.merge(words_key => word)).perform }
    rows = rank(results.map(&:rows))
    Rails.logger.info "[ExternalDb::AskedRun] #{@query.name}: búsqueda parcial por palabra → #{rows.size} fila(s)"
    { query: @query, columns: results.first&.columns || [], rows: rows.first(limit), partial: rows.any? }
  end

  def rank(row_sets)
    scores = Hash.new(0.0)
    row_sets.each do |rows|
      rows.each { |row| scores[row] += 1.0 / rows.size }
    end
    scores.sort_by { |_, score| -score }.map(&:first)
  end

  def words_key
    Array(@query.params_schema).find { |p| p['type'] == 'words' }&.dig('key')
  end

  def words
    words_key ? @params[words_key].to_s.split : []
  end

  def limit
    value = @params['max'].to_i
    (value.positive? ? value : DEFAULT_MAX).clamp(1, MAX_ROWS)
  end
end
