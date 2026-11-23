# frozen_string_literal: true

# == Schema Information
#
# Table name: payment_claims
#
#  id                     :bigint           not null, primary key
#  amount                 :decimal(14, 2)
#  note                   :string
#  reviewed_at            :datetime
#  status                 :string           default("pending"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  conversation_id        :bigint
#  message_id             :bigint
#  receivable_customer_id :bigint           not null
#  reviewed_by_id         :bigint
#
# Indexes
#
#  index_payment_claims_on_account_id              (account_id)
#  index_payment_claims_on_receivable_customer_id  (receivable_customer_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (receivable_customer_id => receivable_customers.id) ON DELETE => cascade
#
# Cobranza — «ya pagué»: lo registra el agente con el comprobante que mandó el cliente (message_id). El cobrador lo
# valida o lo rechaza (Cobranza › Comprobantes). Mientras está pendiente, sus facturas no se cobran (claimed_at);
# validado, siguen así hasta que el corte las traiga pagadas; rechazado, se vuelven a cobrar.
class PaymentClaim < ApplicationRecord
  STATUSES = %w[pending validated rejected].freeze

  belongs_to :account
  belongs_to :receivable_customer
  belongs_to :reviewed_by, class_name: 'User', optional: true

  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: 'pending') }
end
