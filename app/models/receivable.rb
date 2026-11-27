# frozen_string_literal: true

# == Schema Information
#
# Table name: receivables
#
#  id                     :bigint           not null, primary key
#  balance                :decimal(14, 2)   default(0.0), not null
#  claimed_at             :datetime
#  currency               :string           default("MXN"), not null
#  disputed_at            :datetime
#  due_on                 :date             not null
#  folio                  :string           not null
#  issued_on              :date
#  paid_at                :datetime
#  source                 :string           default("upload"), not null
#  status                 :string           default("open"), not null
#  total                  :decimal(14, 2)
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  last_import_id         :bigint
#  receivable_customer_id :bigint           not null
#
# Indexes
#
#  index_receivables_on_account_id                        (account_id)
#  index_receivables_on_account_id_and_status_and_due_on  (account_id,status,due_on)
#  index_receivables_on_customer_folio                    (account_id,receivable_customer_id,folio) UNIQUE
#  index_receivables_on_receivable_customer_id            (receivable_customer_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (receivable_customer_id => receivable_customers.id) ON DELETE => cascade
#
# Cobranza — una factura (documento) de la cartera con su saldo. La crea y la actualiza cada corte
# (Receivables::Snapshot): lo que deja de venir en un corte de su misma fuente queda pagado.
#   status: open | paid
#   disputed_at: está en aclaración (no se cobra) · claimed_at: el cliente dijo «ya pagué» y está por validarse
class Receivable < ApplicationRecord
  STATUSES = %w[open paid].freeze

  belongs_to :account
  belongs_to :receivable_customer
  has_many :events, class_name: 'ReceivableEvent', dependent: :delete_all

  validates :folio, :due_on, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :open_balance, -> { where(status: 'open').where('balance > 0') }
  # Las que el agente puede cobrar: abiertas, sin aclaración ni «ya pagué» pendiente.
  scope :collectable, -> { open_balance.where(disputed_at: nil, claimed_at: nil) }

  def days_overdue(today = Date.current) = (today - due_on).to_i
end
