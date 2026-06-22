# frozen_string_literal: true

# == Schema Information
#
# Table name: case_settings
#
#  id           :bigint           not null, primary key
#  itil_enabled :boolean          default(FALSE), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#
# Indexes
#
#  index_case_settings_on_account_id  (account_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#

# @tickets_cases — Ajustes generales del módulo de tickets por cuenta.
# `itil_enabled = false` (default) = modo simple (osTicket): la UI oculta los
# estados y campos ITIL. El modo es presentación; el backend no se restringe.
class CaseSetting < ApplicationRecord
  belongs_to :account

  def self.for_account(account)
    account.case_setting || account.create_case_setting!
  end
end
