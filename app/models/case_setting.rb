# frozen_string_literal: true

# == Schema Information
#
# Table name: case_settings
#
#  id                       :bigint           not null, primary key
#  itil_enabled             :boolean          default(FALSE), not null
#  reopen_on_customer_reply :boolean          default(TRUE), not null
#  reopen_window_days       :integer          default(30), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  account_id               :bigint           not null
#
# Indexes
#
#  index_case_settings_on_account_id  (account_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#

# @tickets_cases — Ajustes generales del módulo de tickets por cuenta (ventana de
# reapertura). El modo ITIL/simple dejó de ser un ajuste de cuenta y ahora es por
# tipo de caso — ver CaseType#itil_enabled. La columna `itil_enabled` de esta
# tabla sigue en la base (se elimina en un segundo PR) pero ya no se lee ni escribe.
class CaseSetting < ApplicationRecord
  belongs_to :account

  def self.for_account(account)
    account.case_setting || account.create_case_setting!
  end
end
