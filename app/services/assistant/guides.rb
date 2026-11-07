# frozen_string_literal: true

# Asistente (Dali) — las guías de uso de la plataforma. Viven en el repo, en
# config/assistant/guides/*.md (una por tema), y viajan con el código: cuando cambia
# una función, su guía se actualiza en el mismo commit. Dali no las lleva en el
# prompt: las busca (search_guides) y lee solo la que necesita (read_guide).
#
# Cada archivo empieza con una cabecera YAML:
#   ---
#   key: casos                      # igual al nombre del archivo
#   title: Casos y oportunidades
#   areas: [sales, service]         # AccessRole::AREAS; vacío = la ve todo el mundo
#   keywords: [caso, oportunidad, etapa, ganar, perder]
#   pages: [cases, pipeline]        # pantallas de open_page que menciona
#   ---
#   ## Para qué sirve …
#
# Una guía se ve si el usuario tiene al menos una de sus áreas (Access::Grant).
# spec/services/assistant/guides_spec.rb revisa que todas estén completas.
module Assistant::Guides
  DIR = Rails.root.join('config/assistant/guides')
  FRONT_MATTER = /\A---\s*\n(.*?)\n---\s*\n/m
  MAX_RESULTS = 3
  MIN_WORD = 3
  MIN_SCORE = 3 # al menos una palabra clave, o título y texto
  STOPWORDS = %w[como cómo que qué para por con los las del una uno unos unas este esta esto ese esa eso
                 donde dónde cual cuál cuando cuándo puedo puede hago hace hacer quiero tengo tiene sirve
                 sus mis tus son hay muy más mas pero sin ver veo dar sale salir ahi ahí aqui aquí algo
                 dali favor ayuda ayudas usar uso creo crear cambio cambiar cambia pongo poner marco marcar
                 doy hago donde].freeze

  Guide = Struct.new(:key, :title, :areas, :keywords, :pages, :body, keyword_init: true) do
    def visible_to?(grant)
      areas.empty? || areas.any? { |area| grant.allowed?(area) }
    end

    def summary
      body[/^##[^\n]*\n+([^\n]+)/, 1].to_s.truncate(160)
    end
  end

  module_function

  def all
    return load_all if Rails.env.development?

    @all ||= load_all
  end

  def find(key, grant)
    guide = all.find { |g| g.key == key.to_s.strip }
    guide if guide&.visible_to?(grant)
  end

  # → [{ key:, title:, summary: }] de las que mejor coinciden (nada si ninguna).
  def search(text, grant, limit: MAX_RESULTS)
    words = words_of(text)
    return [] if words.empty?

    scored = all.select { |g| g.visible_to?(grant) }.filter_map do |guide|
      score = score(guide, words)
      [guide, score] if score >= MIN_SCORE
    end
    scored.sort_by { |(_g, score)| -score }.first(limit).map do |(guide, _score)|
      { key: guide.key, title: guide.title, summary: guide.summary }
    end
  end

  def normalize(text)
    I18n.transliterate(text.to_s.downcase).gsub(/[^a-z0-9ñ ]+/, ' ').squish
  end

  def words_of(text)
    normalize(text).split.reject { |w| w.length < MIN_WORD || STOPWORDS.include?(w) }.uniq
  end

  # Palabras clave valen más que el título y el título más que el texto.
  # Coincide por raíz (cotizacion ~ cotizaciones, reabro ~ reabrir): la palabra sin sus
  # dos últimas letras, mínimo 5 (contrasena no cae en contrato).
  def stem(word)
    word.length <= 5 ? word : word.first([5, word.length - 2].max)
  end

  def score(guide, words)
    keywords = guide.keywords.map { |k| normalize(k) }.join(' ')
    title = normalize(guide.title)
    body = normalize(guide.body)
    words.sum do |word|
      stem = stem(word)
      (keywords.include?(stem) ? 3 : 0) + (title.include?(stem) ? 2 : 0) + (body.include?(stem) ? 1 : 0)
    end
  end

  def load_all
    Dir[DIR.join('*.md')].map { |path| parse(path) }
  end

  def parse(path)
    raw = File.read(path)
    meta = YAML.safe_load(raw[FRONT_MATTER, 1].to_s) || {}
    Guide.new(key: meta['key'].to_s, title: meta['title'].to_s, areas: Array(meta['areas']).map(&:to_s),
              keywords: Array(meta['keywords']).map(&:to_s), pages: Array(meta['pages']).map(&:to_s),
              body: raw.sub(FRONT_MATTER, '').strip)
  end
end
