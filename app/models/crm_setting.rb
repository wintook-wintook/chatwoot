# == Schema Information
#
# Table name: crm_settings
#
#  id                    :bigint           not null, primary key
#  require_delivery_date :boolean          default(FALSE), not null
#  show_article_notes    :boolean          default(TRUE), not null
#  show_kit_components   :boolean          default(FALSE), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :bigint           not null
#
# Indexes
#
#  index_crm_settings_on_account_id  (account_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#

# CrmZeus Q3.1 — parámetros de CrmZeus de la cuenta (preferencias de la empresa en CRMZeus).
# Si la cuenta nunca los ha guardado, valen los de omisión de la tabla (sin crear el renglón).
class CrmSetting < ApplicationRecord
  belongs_to :account

  def self.for_account(account)
    account.crm_setting || account.build_crm_setting
  end

  def as_crm_json
    slice(:require_delivery_date, :show_article_notes, :show_kit_components)
  end
end
