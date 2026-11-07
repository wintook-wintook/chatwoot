# frozen_string_literal: true

# Publica las guías de uso (config/assistant/guides, Assistant::Guides) como artículos
# del Centro de ayuda GLOBAL de Kontrolya: un solo portal, en la cuenta de Kontrolya,
# público para todos los clientes. Las guías del repo son la única fuente: el artículo
# se reescribe en cada publicación (no se edita a mano en el portal).
#
#   Assistant::GuidePublisher.portal              # el portal (PLATFORM_HELP_PORTAL_SLUG, «ayuda»)
#   Assistant::GuidePublisher.new.call            # crea/actualiza; archiva lo que ya no existe
#   Assistant::GuidePublisher.article_url('casos') # para que Dali dé el enlace
#
# Cada artículo lleva meta.guide_key = clave de la guía y slug «kontrolya-<clave>».
# Categoría: `category:` de la cabecera de la guía o, si no tiene, la de su primera área.
# Se corre con `rake assistant:guides:publish` (idempotente; poner en el deploy).
class Assistant::GuidePublisher
  LOCALE = 'es'
  SLUG_PREFIX = 'kontrolya-'
  DEFAULT_PORTAL_SLUG = 'ayuda'

  # Área → categoría del portal (en el orden en que se muestran).
  CATEGORIES = {
    '' => 'Primeros pasos',
    'conversations' => 'Conversaciones',
    'agenda' => 'Agenda',
    'sales' => 'Ventas',
    'service' => 'Servicio y campo',
    'clients' => 'Clientes',
    'campaigns' => 'Campañas',
    'ai_agents' => 'Agentes IA',
    'reports' => 'Informes',
    'settings' => 'Ajustes y catálogos'
  }.freeze

  Result = Struct.new(:created, :updated, :unchanged, :archived, keyword_init: true)

  def self.portal_slug
    ENV.fetch('PLATFORM_HELP_PORTAL_SLUG', DEFAULT_PORTAL_SLUG)
  end

  def self.portal
    Portal.find_by(slug: portal_slug, archived: false)
  end

  def self.article_url(key)
    portal = self.portal
    return nil unless portal

    article = portal.articles.published.find_by(slug: "#{SLUG_PREFIX}#{key.to_s.dasherize}")
    article && "#{base_url}/hc/#{portal.slug}/articles/#{article.slug}"
  end

  def self.base_url
    ENV.fetch('FRONTEND_URL', '').chomp('/')
  end

  # Crea el portal global en la cuenta indicada (si no existe).
  def self.create_portal!(account:, name: 'Ayuda Kontrolya')
    Portal.find_or_create_by!(slug: portal_slug) do |portal|
      portal.account = account
      portal.name = name
      portal.page_title = name
      portal.header_text = 'Cómo se usa la plataforma'
      portal.color = '#1f93ff'
      portal.config = { 'allowed_locales' => [LOCALE], 'default_locale' => LOCALE }
    end
  end

  def initialize(portal: self.class.portal, author: nil, guides: Assistant::Guides.all)
    raise ArgumentError, "No existe el portal «#{self.class.portal_slug}» (rake assistant:guides:portal)" unless portal

    @portal = portal
    @author = author || default_author
    @guides = guides
    raise ArgumentError, 'La cuenta del portal no tiene un administrador para firmar los artículos' unless @author
  end

  def call
    result = Result.new(created: [], updated: [], unchanged: [], archived: [])
    @guides.each { |guide| publish(guide, result) }
    archive_missing(result)
    result
  end

  private

  def publish(guide, result)
    article = @portal.articles.find_by(slug: slug_for(guide)) || @portal.articles.new(slug: slug_for(guide))
    attrs = article_attrs(guide)
    return result.unchanged << guide.key if article.persisted? && same?(article, attrs)

    created = article.new_record?
    article.assign_attributes(attrs)
    article.save!
    (created ? result.created : result.updated) << guide.key
  end

  def article_attrs(guide)
    { account_id: @portal.account_id, author: @author, title: guide.title, content: guide.body,
      description: guide.summary, category: category_for(guide), status: :published, locale: LOCALE,
      meta: { 'guide_key' => guide.key, 'tags' => guide.keywords.first(10) } }
  end

  def same?(article, attrs)
    article.title == attrs[:title] && article.content == attrs[:content] && article.description == attrs[:description] &&
      article.category_id == attrs[:category].id && article.published? && article.meta.to_h == attrs[:meta]
  end

  # Lo que se publicó antes y ya no tiene guía se archiva (no se borra).
  def archive_missing(result)
    keys = @guides.map { |guide| slug_for(guide) }
    @portal.articles.where('slug LIKE ?', "#{SLUG_PREFIX}%").where.not(slug: keys).where.not(status: :archived).find_each do |article|
      article.update!(status: :archived)
      result.archived << (article.meta.to_h['guide_key'].presence || article.slug)
    end
  end

  def slug_for(guide)
    "#{SLUG_PREFIX}#{guide.key.dasherize}"
  end

  def category_for(guide)
    name = guide.category.presence || CATEGORIES.fetch(guide.areas.first.to_s, CATEGORIES[''])
    @categories ||= {}
    @categories[name] ||= find_or_create_category(name)
  end

  def find_or_create_category(name)
    slug = name.parameterize
    @portal.categories.find_or_create_by!(slug: slug, locale: LOCALE) do |category|
      category.account_id = @portal.account_id
      category.name = name
      category.position = CATEGORIES.values.index(name).to_i + 1
    end
  end

  def default_author
    @portal.account.administrators.order(:id).first
  end
end
