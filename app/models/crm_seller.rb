# == Schema Information
#
# Table name: crm_sellers
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE), not null
#  is_default :boolean          default(FALSE), not null
#  name       :string(100)      not null
#  notes      :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  user_id    :bigint
#
# Indexes
#
#  index_crm_sellers_on_account_id  (account_id)
#  index_crm_sellers_on_user_id     (user_id)
#  index_crm_sellers_unique_name    (account_id, lower((name)::text)) UNIQUE
#  index_crm_sellers_unique_user    (account_id,user_id) UNIQUE WHERE (user_id IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (user_id => users.id) ON DELETE => nullify
#

# CrmZeus O0 — vendedores (VENDEDORES de Microsip). No todos son usuarios de Wintook
# («CAJERO», «MOSTRADOR»…), por eso la liga con el agente es opcional.
class CrmSeller < ApplicationRecord
  include CrmCatalogEntry

  crm_catalog_entry

  belongs_to :user, optional: true

  validates :name, length: { maximum: 100 }
  validates :user_id, uniqueness: { scope: :account_id }, allow_nil: true
  validate :user_belongs_to_account

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }

  private

  def user_belongs_to_account
    return if user.nil? || account.nil?
    return if account.account_users.exists?(user_id: user_id)

    errors.add(:user, 'no pertenece a la cuenta')
  end
end
