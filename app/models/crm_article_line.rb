# == Schema Information
#
# Table name: crm_article_lines
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE), not null
#  is_default :boolean          default(FALSE), not null
#  key        :string(20)
#  name       :string(50)       not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  group_id   :bigint
#
# Indexes
#
#  index_crm_article_lines_on_account_id  (account_id)
#  index_crm_article_lines_on_group_id    (group_id)
#  index_crm_article_lines_unique_name    (account_id, lower((name)::text)) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (group_id => crm_lookups.id) ON DELETE => nullify
#

# CrmZeus A0 — línea de artículos (LINEAS_ARTICULOS de Microsip), agrupada en un grupo
# de líneas (crm_lookups kind line_group).
class CrmArticleLine < ApplicationRecord
  include CrmCatalogEntry

  crm_catalog_entry

  belongs_to :group, class_name: 'CrmLookup', optional: true

  before_validation { self.key = key.to_s.strip.upcase.presence }

  validates :name, length: { maximum: 50 }
  validates :key, length: { maximum: 20 }
  validate :group_is_line_group

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }

  private

  def group_is_line_group
    return if group.nil?

    errors.add(:group, 'no corresponde a ese catálogo') unless group.line_group? && group.account_id == account_id
  end
end
