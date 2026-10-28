# == Schema Information
#
# Table name: crm_payment_term_installments
#
#  id              :bigint           not null, primary key
#  days            :integer          default(0), not null
#  percent         :decimal(5, 2)    default(100.0), not null
#  position        :integer          default(0), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  payment_term_id :bigint           not null
#
# Indexes
#
#  index_crm_payment_term_installments_on_account_id       (account_id)
#  index_crm_payment_term_installments_on_payment_term_id  (payment_term_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (payment_term_id => crm_payment_terms.id) ON DELETE => cascade
#

# CrmZeus O0 — un plazo de una condición de pago: a cuántos días vence y qué % del total.
class CrmPaymentTermInstallment < ApplicationRecord
  belongs_to :account
  belongs_to :payment_term, class_name: 'CrmPaymentTerm', inverse_of: :installments

  before_validation { self.account_id ||= payment_term&.account_id }

  validates :days, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :percent, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
end
