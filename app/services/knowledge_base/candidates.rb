# frozen_string_literal: true

# ================================================================================
# proyecto@predefinidas_que_contestan — JUNTAR CANDIDATAS (paso 1 de buscar y escoger)
# ================================================================================
# Ver KnowledgeBase::Selection. Aquí no se decide nada: se juntan las que PODRÍAN contestar,
# sin miedo a traer de más, para que la correcta casi siempre esté. Tres redes, porque cada
# una ve lo que las otras no:
#
#   exacta      las FICHAS del sujeto en curso (el valor de la variable del tema: PRODUCTO,
#               SUCURSAL, CARRERA…), por su nombre. Entran siempre, primero.
#   palabras    las que traen las palabras de la pregunta en el nombre (vale doble) o en el
#               texto, sin acentos. Encuentra nombres propios, claves y códigos, que la
#               similitud confunde.
#   similitud   las más parecidas por significado («¿abren el domingo?» → «Horario de
#               atención»), con todas las consultas del turno y un umbral bajo.
#
# Palabras y similitud se alternan para que ninguna red se coma los lugares de la otra.
#
#   KnowledgeBase::Candidates.new(scope, queries: ['¿hay otro descuento?', 'Plan X ¿hay otro descuento?'],
#                                 question: '¿hay otro descuento?', subjects: ['Plan X'],
#                                 embed: ->(texto) { vector }).call
#   → [Candidate(item:, via: ['exacta', 'similitud'], similarity: 0.66, words: 1), …]
# ================================================================================
class KnowledgeBase::Candidates
  MAX = 30
  PER_NET = 15
  # Más bajo que el de la búsqueda de siempre (0.20): aquí traer de más no cuesta, decide la IA.
  THRESHOLD = 0.15
  MAX_TERMS = 8
  ACCENTS_FROM = 'áéíóúüñ'
  ACCENTS_TO = 'aeiouun'

  Candidate = Struct.new(:item, :via, :similarity, :words, keyword_init: true)

  def self.terms(question)
    stop = AiFollowUps::KnowledgeSearch::STOPWORDS.to_set { |w| I18n.transliterate(w) }
    I18n.transliterate(question.to_s.downcase).scan(/[a-z0-9]+/)
        .reject { |w| w.size < 3 || stop.include?(w) }
        .map { |w| root(w) }
        .uniq.first(MAX_TERMS)
  end

  # La raíz de una palabra larga, para que «inscribirme» encuentre «inscripción» y
  # «ubicados», «ubicación»; las cortas, sin plural.
  def self.root(word)
    return word[0, ROOT] if word.size >= LONG_WORD

    word.size > 4 ? word.sub(/(?:es|s)\z/, '') : word
  end
  ROOT = 5
  LONG_WORD = 7

  def initialize(scope, queries:, question:, subjects: [], embed: nil)
    @scope = scope
    @queries = Array(queries).compact_blank.uniq
    @question = question.to_s
    @subjects = Array(subjects).compact_blank
    @embed = embed
  end

  def call
    found = {}
    exact.each { |item| add(found, item, 'exacta') }
    alternate(by_similarity, by_words).each do |item, via, value|
      add(found, item, via, value)
    end
    found.values.first(MAX)
  end

  private

  def add(found, item, via, value = nil)
    candidate = found[item.id] ||= Candidate.new(item: item, via: [], similarity: nil, words: 0)
    candidate.via |= [via]
    candidate.similarity = [candidate.similarity, value].compact.max if via == 'similitud'
    candidate.words = [candidate.words, value.to_i].max if via == 'palabras'
  end

  def alternate(first, second)
    Array.new([first.size, second.size].max) { |i| [first[i], second[i]] }.flatten(1).compact
  end

  # Las fichas del sujeto en curso, por su nombre (KnowledgeBase::Selection.same_subject?).
  def exact
    return [] if @subjects.empty?

    @scope.where("knowledge_items.metadata->>'kind' = 'ficha'").to_a.select do |item|
      @subjects.any? { |s| KnowledgeBase::Selection.same_subject?(item.title, s) }
    end
  end

  # [[item, 'similitud', 0.66], …] de la más parecida a la menos.
  def by_similarity
    return [] if @embed.nil?

    best = {}
    @queries.each { |query| keep_best(best, nearest(query)) }
    best.values.sort_by { |_, s| -s }.first(PER_NET).map { |item, s| [item, 'similitud', s] }
  rescue StandardError => e
    Rails.logger.warn "[KBase] ⚠️ Candidatas por similitud: #{e.message}"
    []
  end

  def keep_best(best, pairs)
    pairs.each { |item, s| best[item.id] = [item, s] if s > best.dig(item.id, 1).to_f }
  end

  # [[item, similitud], …] de una consulta.
  def nearest(query)
    vector = @embed.call(query.to_s.first(500))
    return [] if vector.blank?

    @scope.search_by_embedding(vector, limit: PER_NET, threshold: THRESHOLD)
          .map { |item| [item, (1 - item.neighbor_distance.to_f).round(3)] }
  end

  # [[item, 'palabras', puntos], …]: una palabra en el nombre vale 2; en el texto, 1.
  def by_words
    words = self.class.terms(@question)
    return [] if words.empty?

    parts = words.map { |w| word_conditions(w) }
    score = parts.map { |t, b| "(CASE WHEN #{t} THEN 2 ELSE 0 END + CASE WHEN #{b} THEN 1 ELSE 0 END)" }.join(' + ')
    where = parts.map { |t, b| "(#{t} OR #{b})" }.join(' OR ')
    @scope.where(where).select("knowledge_items.*, (#{score}) AS kb_words")
          .reorder(Arel.sql('kb_words DESC, knowledge_items.id')).limit(PER_NET)
          .map { |item| [item, 'palabras', item.read_attribute(:kb_words).to_i] }
  rescue StandardError => e
    Rails.logger.warn "[KBase] ⚠️ Candidatas por palabras: #{e.message}"
    []
  end

  TITLE_SQL = "translate(lower(coalesce(knowledge_items.title, '')), '#{ACCENTS_FROM}', '#{ACCENTS_TO}')".freeze
  BODY_SQL = "translate(lower(knowledge_items.content), '#{ACCENTS_FROM}', '#{ACCENTS_TO}')".freeze

  # [en el nombre, en el texto] para una palabra, sin acentos.
  def word_conditions(word)
    like = "%#{ActiveRecord::Base.sanitize_sql_like(word)}%"
    [ActiveRecord::Base.sanitize_sql_array(["#{TITLE_SQL} LIKE ?", like]),
     ActiveRecord::Base.sanitize_sql_array(["#{BODY_SQL} LIKE ?", like])]
  end
end
