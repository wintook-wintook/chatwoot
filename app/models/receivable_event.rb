# frozen_string_literal: true

# == Schema Information
#
# Table name: receivable_events
#
#  id                   :bigint           not null, primary key
#  amount               :decimal(14, 2)
#  kind                 :string           not null
#  created_at           :datetime         not null
#  account_id           :bigint           not null
#  receivable_id        :bigint           not null
#  receivable_import_id :bigint
#
# Indexes
#
#  index_receivable_events_on_account_id     (account_id)
#  index_receivable_events_on_receivable_id  (receivable_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (receivable_id => receivables.id) ON DELETE => cascade
#
# Cobranza — lo que le pasó a una factura entre cortes: new (apareció), payment (bajó el saldo: abono),
# paid (ya no vino o vino en 0), reopened (volvió a tener saldo). amount = lo que cambió.
class ReceivableEvent < ApplicationRecord
  KINDS = %w[new payment paid reopened].freeze

  belongs_to :account
  belongs_to :receivable

  validates :kind, inclusion: { in: KINDS }
end
