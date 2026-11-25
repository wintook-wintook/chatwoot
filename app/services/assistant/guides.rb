# frozen_string_literal: true

# Asistente (Dali) — las guías de uso de la plataforma. Dali no las lleva en el
# prompt: las busca (search_guides) y lee solo la que necesita (read_guide).
#
# De dónde salen (`all`):
# 1. Del Centro de ayuda «Guías de Dali» (Assistant::GuidePublisher.portal, slug `ayuda-dali`):
#    sus artículos publicados en español con meta.guide_key. Es el mismo portal para TODAS las
#    cuentas: se busca solo por su slug, nunca por Current.account ni por un id de cuenta.
# 2. Si no hay portal (o no tiene guías): de los archivos config/assistant/guides/*.md
#    (`load_files`), que también son la fuente de `rake assistant:guides:publish`.
#
# Cada archivo empieza con una cabecera YAML (en el portal va en article.meta):
#   ---
#   key: casos                      # igual al nombre del archivo
#   title: Casos y oportunidades
#   areas: [sales, service]         # AccessRole::AREAS; vacío = la ve todo el mundo
#   keywords: [caso, oportunidad, etapa, ganar, perder]
#   pages: [cases, pipeline]        # pantallas de open_page que menciona
#   category: Primeros pasos        # opcional: categoría en el Centro de ayuda (Assistant::GuidePublisher)
#   sources: [app/javascript/dashboard/routes/dashboard/contracts/**/*.vue]  # el código que explica
#   reviewed: 2026-11-14            # última revisión contra las pantallas (aunque no cambiara el texto)
#   ---
#   ## Para qué sirve …
#
# Una guía se ve si el usuario tiene al menos una de sus áreas (Access::Grant).
# spec/services/assistant/guides_spec.rb revisa que todas estén completas.
# `sources` sirve para saber cuándo una guía quedó vieja: rake assistant:guides:stale
# (Assistant::GuideFreshness) lista las guías cuyo código cambió después de su último commit.
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

  Guide = Struct.new(:key, :title, :areas, :keywords, :pages, :body, :category, :sources, :reviewed,
                     keyword_init: true) do
    def visible_to?(grant)
      areas.empty? || areas.any? { |area| grant.allowed?(area) }
    end

    def summary
      body[/^##[^\n]*\n+([^\n]+)/, 1].to_s.truncate(160)
    end
  end

  module_function

  # En producción se memoriza hasta reiniciar (paso 6 del plan: caché que se vacía al editar).
  def all
    return load_all unless Rails.env.production?

    @all ||= load_all
  end

  # Por su clave; si el modelo manda el título («Dali en el teléfono (instalarlo como app)»), también.
  def find(key, grant)
    wanted = key.to_s.strip
    guide = all.find { |g| g.key == wanted } || all.find { |g| normalize(g.title) == normalize(wanted) }
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

  # «puedo», «pueden», «puedem», «podemos», «podria»…: el verbo poder no dice de qué es la pregunta.
  PODER = /\A(?:pued|pod[eir])/

  def words_of(text)
    normalize(text).split.reject { |w| w.length < MIN_WORD || STOPWORDS.include?(w) || w.match?(PODER) }.uniq
  end

  # Palabras clave valen más que el título y el título más que el texto.
  # Coincide por raíz (cotizacion ~ cotizaciones, reabro ~ reabrir): la palabra sin sus
  # dos últimas letras, mínimo 5 (contrasena no cae en contrato).
  def stem(word)
    word.length <= 5 ? word : word.first([5, word.length - 2].max)
  end

  # Las faltas de ortografía más comunes suenan igual: «mensiones» = «menciones»,
  # «bendedor» = «vendedor», «aser» = «hacer», «llamada» = «yamada». Se comparan así los dos lados.
  def sound(text)
    text.gsub('ch', "\u0001").gsub(/c(?=[ei])|z/, 's').tr('v', 'b').gsub('ll', 'y').delete('h').tr("\u0001", 'c')
  end

  def score(guide, words)
    keywords = sound(guide.keywords.map { |k| normalize(k) }.join(' '))
    title = sound(normalize(guide.title))
    body = sound(normalize(guide.body))
    words.sum do |word|
      stem = stem(sound(word))
      (keywords.include?(stem) ? 3 : 0) + (title.include?(stem) ? 2 : 0) + (body.include?(stem) ? 1 : 0)
    end
  end

  def load_all
    guides = load_portal
    return guides if guides.any?

    warn_once("[Assistant::Guides] sin portal #{Assistant::GuidePublisher.portal_slug}: usando archivos")
    load_files
  end

  # Las guías del portal «Guías de Dali» (Assistant::GuidePortalSource).
  def load_portal
    Assistant::GuidePortalSource.load
  end

  def warn_once(message)
    return if @warned

    @warned = true
    Rails.logger.warn(message)
  end

  # Una guía con la cabecera rota se salta (y queda en el log) sin tumbar las demás;
  # `rake assistant:guides:check` y su spec sí la marcan.
  def load_files
    Dir[DIR.join('*.md')].filter_map do |path|
      parse(path)
    rescue Psych::Exception => e
      Rails.logger.error("[Assistant::Guides] #{File.basename(path)}: cabecera inválida (#{e.message})")
      nil
    end
  end

  def broken_files
    Dir[DIR.join('*.md')].filter_map do |path|
      parse(path)
      nil
    rescue Psych::Exception => e
      "#{File.basename(path)}: #{e.message}"
    end
  end

  def parse(path)
    raw = File.read(path)
    meta = YAML.safe_load(raw[FRONT_MATTER, 1].to_s, permitted_classes: [Date]) || {}
    lists = %w[areas keywords pages sources].index_with { |field| Array(meta[field]).map(&:to_s) }
    Guide.new(key: meta['key'].to_s, title: meta['title'].to_s, **lists.symbolize_keys,
              category: meta['category'].to_s.presence, reviewed: meta['reviewed'].to_s.presence,
              body: raw.sub(FRONT_MATTER, '').strip)
  end
end
