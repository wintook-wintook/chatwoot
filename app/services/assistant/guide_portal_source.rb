# frozen_string_literal: true

# Las guías de Dali leídas del Centro de ayuda «Guías de Dali» (Assistant::GuidePublisher.portal):
# artículos publicados, en español, con meta.guide_key. Arma el mismo Assistant::Guides::Guide
# que los archivos .md, en el mismo orden (por clave = nombre del archivo).
#
# El portal se busca SOLO por su slug: nunca por Current.account ni por un id de cuenta,
# porque es el mismo para todas las cuentas.
module Assistant::GuidePortalSource
  LISTS = %w[areas keywords pages sources].freeze

  module_function

  def load
    portal = Assistant::GuidePublisher.portal
    return [] unless portal

    portal.articles.published.where(locale: Assistant::GuidePublisher::LOCALE)
          .where("COALESCE(articles.meta->>'guide_key', '') <> ''").includes(:category)
          .map { |article| guide_for(article) }.sort_by(&:key)
  end

  def guide_for(article)
    meta = article.meta.to_h
    lists = LISTS.index_with { |field| Array(meta[field]).map(&:to_s) }
    Assistant::Guides::Guide.new(key: meta['guide_key'].to_s, title: article.title.to_s, **lists.symbolize_keys,
                                 category: article.category&.name, reviewed: meta['reviewed'].to_s.presence,
                                 body: article.content.to_s)
  end
end
