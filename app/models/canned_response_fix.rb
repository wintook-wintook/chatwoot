# frozen_string_literal: true

# == Schema Information
#
# Table name: canned_response_fixes
#
#  id                 :bigint           not null, primary key
#  batch              :string
#  checks             :jsonb            not null
#  error              :string
#  input              :jsonb            not null
#  kind               :string           default("oversize"), not null
#  proposal           :jsonb            not null
#  result             :jsonb            not null
#  snapshot           :jsonb            not null
#  source_digest      :string
#  source_digests     :jsonb            not null
#  source_ids         :jsonb            not null
#  status             :string           default("running"), not null
#  undone_at          :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :integer          not null
#  canned_response_id :integer
#  finding_id         :bigint
#  user_id            :integer
#
# Indexes
#
#  index_canned_response_fixes_on_account_id             (account_id)
#  index_canned_response_fixes_on_account_id_and_status  (account_id,status)
#  index_canned_response_fixes_on_batch                  (batch)
#  index_canned_response_fixes_on_canned_response_id     (canned_response_id)
#  index_canned_response_fixes_on_finding_id             (finding_id)
#  index_canned_response_fixes_on_user_id                (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (canned_response_id => canned_responses.id) ON DELETE => nullify
#  fk_rails_...  (finding_id => canned_response_findings.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id) ON DELETE => nullify
#
# ================================================================================
# proyecto@arreglar_predefinidas — UNA PROPUESTA DE «ARREGLAR CON IA»
# ================================================================================
# running → proposed → applied → undone          (failed / discarded en el camino)
#
# kind      oversize  pasa del tope de caracteres (Fix::Builder)
#           writing   mejorar redacción, solo lo señalado (Fix::WritingBuilder)
#           merge     unir duplicadas o que se solapan en una (Fix::MergeBuilder)
#           separate  dos que se solapan: cada una con su tema (Fix::MergeBuilder)
#           resolve   contradicción: corregir con el dato que eligió la persona
#                     (Fix::ResolveBuilder)
# source_ids / source_digests   las predefinidas de origen y la huella de su texto al
#           proponer: si una cambia o desaparece, la propuesta ya no aplica (stale).
# proposal  { action:, parts: [{ short_code:, content: }], questions: [...], … }
# checks    los candados (CannedResponses::Fix::Checks)
# input     lo que eligió la persona (resolve: choices, extra_ids; writing: issues)
# snapshot  cómo estaban las de origen antes de aplicar → «Deshacer» (Fix::Undo)
# result    { created_ids:, updated_ids:, deleted_ids:, applied_digests: }
# ================================================================================

class CannedResponseFix < ApplicationRecord
  STATUSES = %w[running proposed applied discarded failed undone].freeze
  KINDS = %w[oversize writing merge separate resolve].freeze
  ACTIONS = %w[clean split condense mark_prompt keep rewrite merge separate resolve].freeze
  STALE_AFTER = 10.minutes
  UNDO_DAYS = 30

  belongs_to :account
  belongs_to :canned_response, optional: true
  belongs_to :finding, class_name: 'CannedResponseFinding', optional: true
  belongs_to :user, optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :kind, inclusion: { in: KINDS }

  scope :active, -> { where(status: %w[running proposed]) }

  def self.digest_for(response) = Digest::SHA1.hexdigest(response.agent_text)

  # Las de origen, en el orden de source_ids (las que ya no existen, fuera).
  def sources
    por_id = account.canned_responses.where(id: source_ids).index_by(&:id)
    source_ids.filter_map { |id| por_id[id] }
  end

  def stale_source?
    actuales = sources
    return true if actuales.size != source_ids.size

    actuales.any? { |r| source_digests[r.id.to_s] != self.class.digest_for(r) }
  end

  # Una «running» de más de STALE_AFTER se dio por muerta (se reinició Sidekiq).
  def dead? = status == 'running' && created_at < STALE_AFTER.ago

  def undoable? = status == 'applied' && snapshot.present? && updated_at > UNDO_DAYS.days.ago

  def as_fix_json
    { id: id, kind: kind, status: dead? ? 'failed' : status, error: dead? ? 'timeout' : error,
      proposal: proposal, checks: checks, result: result, input: input, finding_id: finding_id, batch: batch,
      stale: status == 'proposed' && stale_source?, undoable: undoable?, undone_at: undone_at,
      created_at: created_at, updated_at: updated_at,
      originals: sources.map(&:form_json), original: sources.first&.form_json,
      snapshot_names: snapshot.pluck('short_code') }
  end
end
