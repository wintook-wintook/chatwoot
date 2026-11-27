# == Schema Information
#
# Table name: crm_article_taxes
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  article_id :bigint           not null
#  tax_id     :bigint           not null
#
# Indexes
#
#  index_crm_article_taxes_on_account_id             (account_id)
#  index_crm_article_taxes_on_article_id             (article_id)
#  index_crm_article_taxes_on_article_id_and_tax_id  (article_id,tax_id) UNIQUE
#  index_crm_article_taxes_on_tax_id                 (tax_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (article_id => crm_articles.id) ON DELETE => cascade
#  fk_rails_...  (tax_id => crm_taxes.id) ON DELETE => cascade
#

# CrmZeus A0 — impuesto que lleva un artículo (IMPUESTOS_ARTICULOS): puede llevar varios.
class CrmArticleTax < ApplicationRecord
  belongs_to :account
  belongs_to :article, class_name: 'CrmArticle', inverse_of: :article_taxes
  belongs_to :tax, class_name: 'CrmTax'

  before_validation { self.account_id ||= article&.account_id }

  validates :tax_id, uniqueness: { scope: :article_id }
  validate { errors.add(:tax, 'no pertenece a la cuenta') if tax && tax.account_id != account_id }
end
