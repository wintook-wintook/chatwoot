# frozen_string_literal: true

# == Schema Information
#
# Table name: receivable_imports
#
#  id         :bigint           not null, primary key
#  source     :string           default("upload"), not null
#  source_ref :string
#  stats      :jsonb            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  user_id    :bigint
#
# Indexes
#
#  index_receivable_imports_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
# Cobranza — un corte de la cartera aplicado (Receivables::Snapshot): de qué fuente vino (un Excel/CSV subido o, más
# adelante, la sincronización con el sistema administrativo), quién lo hizo y qué cambió.
# stats: { rows, valid, customers, invoices, errors: [{ row, reason }], totals: { MXN: … }, aging: {…},
#          diff: { new, paid, payments, payments_amount, reopened }, unlinked }
class ReceivableImport < ApplicationRecord
  belongs_to :account
  belongs_to :user, optional: true

  validates :source, presence: true
end
