# frozen_string_literal: true

# Seguimiento IA — lo que el agente consulta: las RESPUESTAS PREDEFINIDAS de la empresa
# (herramienta buscar_respuesta_predefinida). Lo demás que sabe del cliente es su nota IA,
# que va directo en el prompt (AiFollowUps::Prompt). Decisión del usuario 2026-11-06: nada de
# artículos, documentos, hojas ni páginas web.
#
#   search = AiFollowUps::KnowledgeSearch.new(account: account)
#   search.canned_available? → hay predefinidas que puede usar
#   search.canned(pregunta)  → resultados
#
# Primero por significado (embeddings de knowledge_items de la fuente «Respuestas
# predefinidas»); si no hay nada vectorizado o no encuentra, por palabras en canned_responses.
# Las que son prompt o llevan instrucciones (content_is_prompt / content_prompts, como en el
# motor de siempre: KnowledgeBase::CannedPrompt) se entregan con las instrucciones aparte,
# marcadas como internas.
class AiFollowUps::KnowledgeSearch < Cases::Ai::BaseService
  LIMIT = 3
  THRESHOLD = 0.25
  MAX_CHARS = 1200
  CANNED = 'canned_response'
  STOPWORDS = %w[
    el la los las un una unos unas de del al a en y o u que qué con por para como cómo es son se su sus
    lo le les me mi mis tu tus te nos ya hay muy mas más pero si sí no cual cuál cuando cuándo donde dónde
    tienen tiene tengo quiero quisiera puedo pueden favor hola buenas buenos dias días tardes noches
  ].to_set.freeze

  # Hay predefinidas y, si la cuenta configuró su fuente, que esté activa.
  def canned_available?
    source = @account.knowledge_sources.find_by(source_type: CANNED)
    return false if source && source.status != 'active'

    @account.canned_responses.exists?
  end

  def canned(question)
    return { error: 'Falta la pregunta.' } if question.blank?
    return { results: [], note: 'La empresa no tiene respuestas predefinidas disponibles.' } unless canned_available?

    responses = semantic(question).presence || keyword(question)
    return { results: [], note: 'No hay respuesta predefinida para eso. No lo inventes.' } if responses.empty?

    { results: responses.map { |c| canned_result(c) } }
  end

  private

  def semantic(question)
    scope = KnowledgeItem.where(account_id: @account.id, source_type: CANNED).where.not(embedding: nil)
    return [] unless scope.exists?

    vector = embed(question.to_s.first(500))
    return [] if vector.blank?

    ids = scope.search_by_embedding(vector, limit: LIMIT, threshold: THRESHOLD).map(&:source_id).uniq.first(LIMIT)
    @account.canned_responses.where(id: ids).index_by(&:id).values_at(*ids).compact
  end

  # Por palabras: cada palabra significativa suma; gana la que más tenga.
  def keyword(question)
    words = terms(question)
    return [] if words.empty?

    score = words.map { |w| "(CASE WHEN #{match_sql(w)} THEN 1 ELSE 0 END)" }.join(' + ')
    @account.canned_responses.where(words.map { |w| "(#{match_sql(w)})" }.join(' OR '))
            .reorder(Arel.sql("#{score} DESC")).limit(LIMIT).to_a
  end

  def terms(question)
    question.to_s.downcase.scan(/[[:alnum:]]+/).reject { |w| w.size < 3 || STOPWORDS.include?(w) }.uniq.first(8)
  end

  def match_sql(word)
    %w[canned_responses.short_code canned_responses.content].map do |column|
      ActiveRecord::Base.sanitize_sql_array(["#{column} ILIKE ?", "%#{word}%"])
    end.join(' OR ')
  end

  def canned_result(canned)
    base = { codigo: canned.short_code }
    if canned.content_is_prompt
      base.merge(tipo: 'instrucciones', instrucciones_internas: canned.content.to_s.first(MAX_CHARS * 2))
    elsif canned.content_prompts.present?
      base.merge(tipo: 'informacion_con_instrucciones', informacion: canned.content.to_s.first(MAX_CHARS),
                 instrucciones_internas: canned.content_prompts.to_s.first(MAX_CHARS))
    else
      base.merge(tipo: 'informacion', informacion: canned.content.to_s.first(MAX_CHARS))
    end
  end
end
