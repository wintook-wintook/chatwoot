# == Schema Information
#
# Table name: crm_article_prices
#
#  id            :bigint           not null, primary key
#  price         :decimal(18, 6)   default(0.0), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :bigint           not null
#  article_id    :bigint           not null
#  currency_id   :bigint
#  price_list_id :bigint           not null
#
# Indexes
#
#  index_crm_article_prices_on_account_id                    (account_id)
#  index_crm_article_prices_on_article_id                    (article_id)
#  index_crm_article_prices_on_article_id_and_price_list_id  (article_id,price_list_id) UNIQUE
#  index_crm_article_prices_on_currency_id                   (currency_id)
#  index_crm_article_prices_on_price_list_id                 (price_list_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (article_id => crm_articles.id) ON DELETE => cascade
#  fk_rails_...  (currency_id => crm_currencies.id) ON DELETE => nullify
#  fk_rails_...  (price_list_id => crm_lookups.id) ON DELETE => cascade
#

# CrmZeus A0 — precio de un artículo en una lista de precios (PRECIOS_ARTICULOS), en su moneda.
class CrmArticlePrice < ApplicationRecord
  DUPLICATE_MESSAGE = 'ya tiene precio en este artículo'.freeze

  belongs_to :account
  belongs_to :article, class_name: 'CrmArticle', inverse_of: :prices
  belongs_to :price_list, class_name: 'CrmLookup'
  belongs_to :currency, class_name: 'CrmCurrency', optional: true

  before_validation { self.account_id ||= article&.account_id }

  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :price_list_id, uniqueness: { scope: :article_id, message: DUPLICATE_MESSAGE }
  validate :references_match

  private

  def references_match
    errors.add(:price_list, 'no corresponde a ese catálogo') if price_list && (!price_list.price_list? || price_list.account_id != account_id)
    errors.add(:currency, 'no pertenece a la cuenta') if currency && currency.account_id != account_id
  end
end
