# frozen_string_literal: true

# ================================================================================
# proyecto@erp_productos — UNA {{consulta:}} CON "?", DE PUNTA A PUNTA (sin redactar)
# ================================================================================
# Plan: docs/erp_productos_plan.md (§3.2). Lo usa el motor (KnowledgeBaseResponseService)
# cuando la directiva del turno pide parámetros a la IA:
#
#   1. encuentra la consulta (mismas reglas de conexión que el render de siempre);
#   2. la IA llena SOLO los "?" (ExternalDb::AskedParams);
#   3. se suman los valores fijos —que siempre ganan—, el posicional y el RFC del contacto;
#   4. corre con el QueryRunner (solo SELECT, binds, tope) y recorta a `max`.
#   5. si el texto tenía varias palabras y no hubo resultados, busca con cada palabra por
#      separado y marca el resultado como PARCIAL (medido: el catálogo tenía "AIERE
#      ACONDICIONADO TOSHIBA" y "aire acondicionado toshiba" no encontraba nada). El motor
#      se lo dice al modelo, que los presenta como "podrían ser", no como lo pedido.
#
# Devuelve { query:, rows:, columns: } o nil = no aplica (el mensaje no pide esta
# consulta, la IA no respondió, la consulta no existe o falló): el motor sigue su camino
# y el agente contesta como siempre, sin inventar datos.
# ================================================================================
class ExternalDb::AskedConsulta
  DEFAULT_MAX = 5
  MAX_ROWS = 10

  # conversation: de ahí salen la cuenta, el inbox (conexión por defecto y modelo) y el
  # contacto (su RFC).
  def initialize(source:, question:, conversation:, history: [])
    @source = source
    @question = question
    @inbox = conversation.inbox
    @history = history
    @renderer = ExternalDb::ConsultaDirectiveRenderer.new(account: conversation.account, contact: conversation.contact,
                                                          inbox: @inbox)
  end

  def call
    directive = ExternalDb::ConsultaDirectiveRenderer.parse(@source).find(&:asks?)
    query = directive && @renderer.resolve(directive)
    return log(nil, "consulta '#{directive&.name}' no encontrada") unless query

    filled = ExternalDb::AskedParams.new(query: query, asked: directive.asked, question: @question, inbox: @inbox,
                                         history: @history).call
    return log(nil, "#{query.name}: el mensaje no la pide o la IA no respondió") unless filled && filled[:use]

    run(query, @renderer.params_for(directive, query, filled[:params]))
  end

  private

  def run(query, params)
    result = ExternalDb::QueryRunner.new(query, params).perform
    Rails.logger.info "[ExternalDb::AskedConsulta] #{query.name} #{params.inspect} → #{result.row_count} fila(s)"
    return partial(query, params) if result.rows.empty? && words_param(query, params).to_s.split.size > 1

    { query: query, columns: result.columns, rows: result.rows.first(limit(params)), partial: false }
  rescue ExternalDb::QueryRunner::ParamError, StandardError => e
    log(nil, "#{query.name}: #{e.message}")
  end

  # Una búsqueda por palabra, ordenadas por relevancia: cada palabra vale 1 / (cuántos
  # productos la tienen), así la más específica manda. Medido: con "aire acondicionado
  # toshiba", en el orden de las palabras los de "aire" llenaban los 5 lugares y el único
  # Toshiba quedaba fuera.
  def partial(query, params)
    key = words_key(query)
    results = params[key].to_s.split.map { |word| ExternalDb::QueryRunner.new(query, params.merge(key => word)).perform }
    rows = rank(results.map(&:rows))
    Rails.logger.info "[ExternalDb::AskedConsulta] #{query.name}: búsqueda parcial por palabra → #{rows.size} fila(s)"
    { query: query, columns: results.first&.columns || [], rows: rows.first(limit(params)), partial: rows.any? }
  end

  def rank(row_sets)
    scores = Hash.new(0.0)
    row_sets.each do |rows|
      rows.each { |row| scores[row] += 1.0 / rows.size }
    end
    scores.sort_by { |_, score| -score }.map(&:first)
  end

  def words_key(query)
    Array(query.params_schema).find { |p| p['type'] == 'words' }&.dig('key')
  end

  def words_param(query, params)
    key = words_key(query)
    key && params[key]
  end

  def limit(params)
    value = params['max'].to_i
    (value.positive? ? value : DEFAULT_MAX).clamp(1, MAX_ROWS)
  end

  def log(value, reason)
    Rails.logger.info "[ExternalDb::AskedConsulta] ⏭️ #{reason}"
    value
  end
end
