# frozen_string_literal: true

# == Schema Information
#
# Table name: canned_response_audits
#
#  id          :bigint           not null, primary key
#  error       :string
#  finished_at :datetime
#  stats       :jsonb            not null
#  status      :string           default("running"), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :integer          not null
#
# Indexes
#
#  index_canned_response_audits_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#

class CannedResponseAudit < ApplicationRecord
  STATUSES = %w[running done failed].freeze
  STALE_AFTER = 30.minutes

  belongs_to :account

  validates :status, inclusion: { in: STATUSES }

  scope :running, -> { where(status: 'running').where('created_at > ?', STALE_AFTER.ago) }

  def as_audit_json
    { id: id, status: status, stats: stats, error: error, started_at: created_at, finished_at: finished_at }
  end
end
