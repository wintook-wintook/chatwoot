# frozen_string_literal: true

# CrmZeus — las tablas crm_* de la cuenta. Viven aquí para no pasar a Account del
# límite de Metrics/ClassLength. Al borrar la cuenta se destruyen antes que lo demás
# (apuntan a contactos y usuarios; nada apunta a ellas) y en este orden entre sí.
module CrmZeusAccount
  extend ActiveSupport::Concern

  included do
    has_many :crm_quotes, dependent: :destroy # CrmZeus Q0 (antes que las organizaciones: su FK es restrictiva)
    has_many :crm_quote_series, dependent: :delete_all # CrmZeus Q0
    has_one :crm_setting, dependent: :delete # CrmZeus Q3.1
    has_many :crm_organizations, dependent: :destroy # CrmZeus O0
    has_many :crm_lookups, dependent: :destroy # CrmZeus O0
    has_many :crm_sellers, dependent: :destroy # CrmZeus O0
    has_many :crm_payment_terms, dependent: :destroy # CrmZeus O0
    has_many :crm_currencies, dependent: :destroy # CrmZeus O0
    has_many :crm_countries, dependent: :destroy # CrmZeus O0
    # Antes que los artículos: un artículo que es componente de un kit no se deja borrar.
    has_many :crm_article_components, dependent: :delete_all # CrmZeus A3
    has_many :crm_articles, dependent: :destroy # CrmZeus A0
    has_many :crm_article_lines, dependent: :destroy # CrmZeus A0
    has_many :crm_units, dependent: :destroy # CrmZeus A0
    has_many :crm_taxes, dependent: :destroy # CrmZeus A0
  end
end
