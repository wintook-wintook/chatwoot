# frozen_string_literal: true

# == Schema Information
#
# Table name: canned_response_findings
#
#  id                       :bigint           not null, primary key
#  details                  :jsonb            not null
#  digest                   :string           not null
#  kind                     :string           not null
#  severity                 :string           default("medium"), not null
#  similarity               :float
#  status                   :string           default("open"), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  account_id               :integer          not null
#  canned_response_id       :integer          not null
#  other_canned_response_id :integer
#
# Indexes
#
#  index_canned_response_findings_on_account_id                (account_id)
#  index_canned_response_findings_on_account_id_and_status     (account_id,status)
#  index_canned_response_findings_on_canned_response_id        (canned_response_id)
#  index_canned_response_findings_on_other_canned_response_id  (other_canned_response_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (canned_response_id => canned_responses.id) ON DELETE => cascade
#  fk_rails_...  (other_canned_response_id => canned_responses.id) ON DELETE => cascade
#

class CannedResponseFinding < ApplicationRecord
  KINDS = %w[duplicate overlap contradiction writing].freeze
  SEVERITIES = %w[high medium low].freeze
  STATUSES = %w[open dismissed].freeze

  belongs_to :account
  belongs_to :canned_response
  belongs_to :other_canned_response, class_name: 'CannedResponse', optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :severity, inclusion: { in: SEVERITIES }
  validates :status, inclusion: { in: STATUSES }
  validates :digest, presence: true

  scope :unresolved, -> { where(status: 'open') }
  scope :dismissed, -> { where(status: 'dismissed') }
  scope :involving, ->(ids) { where(canned_response_id: ids).or(where(other_canned_response_id: ids)) }

  # La huella del texto de una o dos predefinidas (en el orden del par).
  def self.digest_for(*responses)
    Digest::SHA1.hexdigest(responses.compact.map(&:agent_text).join("\u0000"))
  end

  def ids = [canned_response_id, other_canned_response_id].compact

  def as_audit_json
    {
      id: id, kind: kind, severity: severity, status: status, similarity: similarity&.round(3),
      details: details, created_at: created_at,
      responses: [canned_response, other_canned_response].compact.map(&:form_json)
    }
  end
end
