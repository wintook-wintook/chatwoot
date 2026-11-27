# == Schema Information
#
# Table name: crm_article_components
#
#  id             :bigint           not null, primary key
#  position       :integer          default(0), not null
#  quantity       :decimal(18, 5)   default(1.0), not null
#  replaceable    :boolean          default(FALSE), not null
#  units_editable :boolean          default(FALSE), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :bigint           not null
#  article_id     :bigint           not null
#  component_id   :bigint           not null
#
# Indexes
#
#  index_crm_article_components_on_account_id                   (account_id)
#  index_crm_article_components_on_article_id                   (article_id)
#  index_crm_article_components_on_article_id_and_component_id  (article_id,component_id) UNIQUE
#  index_crm_article_components_on_component_id                 (component_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (article_id => crm_articles.id) ON DELETE => cascade
#  fk_rails_...  (component_id => crm_articles.id)
#

# CrmZeus A3 — componente de un artículo kit (JUEGOS_DET): qué artículo lleva y cuántas
# unidades. «Reemplazable» y «permite cambiar unidades» se usarán al cotizar, donde el kit
# no almacenable se desglosa en sus componentes (precio 0; el precio es el del kit).
class CrmArticleComponent < ApplicationRecord
  DUPLICATE_MESSAGE = 'ya está en este kit'.freeze

  belongs_to :account
  belongs_to :article, class_name: 'CrmArticle', inverse_of: :components
  belongs_to :component, class_name: 'CrmArticle'

  before_validation { self.account_id ||= article&.account_id }

  validates :quantity, numericality: { greater_than: 0 }
  validates :component_id, uniqueness: { scope: :article_id, message: DUPLICATE_MESSAGE }
  validate :component_is_valid

  private

  def component_is_valid
    return unless component

    errors.add(:component, 'no pertenece a la cuenta') if component.account_id != account_id
    errors.add(:component, 'no puede ser el mismo kit') if article && component.id == article.id
    errors.add(:component, 'no puede ser otro kit') if component.is_kit?
  end
end
