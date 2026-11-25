# frozen_string_literal: true

# Artículos del Centro de ayuda «Guías de Dali» (Assistant::GuidePublisher.portal_slug).
# Son las guías con las que Dali contesta en TODAS las cuentas: en `meta` llevan la cabecera
# de la guía (guide_key, areas, keywords, pages, sources, reviewed).
#
# - Un artículo nuevo creado desde la pantalla recibe slug «kontrolya-<clave>» y su guide_key,
#   para que Dali lo encuentre y dé su enlace (GuidePublisher.article_url).
# - areas y pages solo aceptan valores que existen (AccessRole::AREAS, Assistant::Pages::MAP).
# - guide_key y sources no se editan desde la pantalla (ver Api::V1::Accounts::ArticlesController).
module DaliGuideArticle
  extend ActiveSupport::Concern

  # Lo que el editor del Centro de ayuda puede cambiar, además de title/description/tags.
  EDITABLE_META = [{ areas: [] }, { keywords: [] }, { pages: [] }, :reviewed].freeze
  REVIEWED_FORMAT = /\A\d{4}-\d{2}-\d{2}\z/

  included do
    before_validation :assign_dali_guide_key, on: :create, if: :dali_guide?
    validate :validate_dali_guide_meta, if: :dali_guide?
  end

  class_methods do
    def dali_portal?(portal)
      portal.present? && portal.slug == Assistant::GuidePublisher.portal_slug
    end
  end

  def dali_guide?
    self.class.dali_portal?(portal)
  end

  def dali_guide_key
    meta.to_h['guide_key'].presence
  end

  private

  # El publicador ya trae slug y guide_key; desde la pantalla solo llega el título.
  def assign_dali_guide_key
    return if dali_guide_key || title.blank?

    self.slug = unique_dali_slug(title.parameterize) if slug.blank?
    key = slug.delete_prefix(Assistant::GuidePublisher::SLUG_PREFIX).tr('-', '_')
    self.meta = meta.to_h.merge('guide_key' => key)
  end

  def unique_dali_slug(base)
    prefix = Assistant::GuidePublisher::SLUG_PREFIX
    candidate = "#{prefix}#{base}"
    suffix = 1
    candidate = "#{prefix}#{base}-#{suffix += 1}" while Article.exists?(slug: candidate)
    candidate
  end

  def validate_dali_guide_meta
    data = meta.to_h
    validate_known(data['areas'], AccessRole::AREAS, 'áreas desconocidas')
    validate_known(data['pages'], Assistant::Pages::MAP.keys, 'pantallas desconocidas')
    reviewed = data['reviewed'].to_s
    errors.add(:meta, 'la fecha de revisión debe ser AAAA-MM-DD') if reviewed.present? && !reviewed.match?(REVIEWED_FORMAT)
  end

  def validate_known(values, allowed, message)
    unknown = Array(values).map(&:to_s) - allowed
    errors.add(:meta, "#{message}: #{unknown.join(', ')}") if unknown.any?
  end
end
