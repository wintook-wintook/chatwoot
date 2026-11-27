# == Schema Information
#
# Table name: demo_imports
#
#  id          :bigint           not null, primary key
#  created_ids :jsonb            not null
#  name        :string           not null
#  source      :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#  user_id     :bigint
#
# Indexes
#
#  index_demo_imports_on_account_id  (account_id)
#  index_demo_imports_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => nullify
#
# Ajustes › Demostraciones — una importación de un kit de demo (DemoKits::Importer). `created_ids` guarda lo que creó
# (para limpiar o quitar la demo sin tocar lo que ya tenía la cuenta):
#   { 'catalog_item_ids' => [], 'catalog_category_ids' => [], 'inbox_ids' => [], 'tracking_template_ids' => [],
#     'canned_response_ids' => [] }
class DemoImport < ApplicationRecord
  KEYS = %w[catalog_item_ids catalog_category_ids inbox_ids tracking_template_ids canned_response_ids].freeze

  belongs_to :account
  belongs_to :user, optional: true

  validates :name, presence: true, length: { maximum: 200 }

  def ids(key) = Array(created_ids.to_h[key.to_s]).map(&:to_i)
end
