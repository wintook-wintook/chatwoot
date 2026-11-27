# frozen_string_literal: true

# == Schema Information
#
# Table name: payment_promises
#
#  id                     :bigint           not null, primary key
#  amount                 :decimal(14, 2)
#  note                   :string
#  promised_on            :date             not null
#  status                 :string           default("pending"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  conversation_id        :bigint
#  receivable_customer_id :bigint           not null
#
# Indexes
#
#  index_payment_promises_on_account_id              (account_id)
#  index_payment_promises_on_receivable_customer_id  (receivable_customer_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (receivable_customer_id => receivable_customers.id) ON DELETE => cascade
#
# Cobranza — «pago el viernes»: la registra el agente (Motor2::Skills::Collections). Mientras esté pendiente y no pase
# la fecha, al cliente no se le vuelve a cobrar; los cortes la marcan cumplida (kept) o incumplida (broken)
# (Receivables::Promises).
class PaymentPromise < ApplicationRecord
  STATUSES = %w[pending kept broken].freeze

  belongs_to :account
  belongs_to :receivable_customer

  validates :promised_on, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: 'pending') }
end
