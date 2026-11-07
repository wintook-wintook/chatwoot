# frozen_string_literal: true

# == Schema Information
#
# Table name: assistant_guide_gaps
#
#  id              :bigint           not null, primary key
#  answer          :text
#  guide_key       :string
#  last_asked_at   :datetime         not null
#  normalized      :string           not null
#  occurrences     :integer          default(1), not null
#  page            :string
#  question        :text             not null
#  reason          :string           not null
#  resolution_note :string
#  status          :string           default("pending"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  user_id         :bigint
#
# Indexes
#
#  index_assistant_guide_gaps_dedupe                       (account_id,normalized,reason,status)
#  index_assistant_guide_gaps_on_account_id                (account_id)
#  index_assistant_guide_gaps_on_status_and_last_asked_at  (status,last_asked_at)
#  index_assistant_guide_gaps_on_user_id                   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => nullify
#
# Asistente (Dali) — una pregunta de uso que Dali no supo contestar. Sirve para
# escribir o corregir las guías (config/assistant/guides); la ve solo el Super Admin
# (SuperAdmin::AssistantGuideGapsController) y se lee con `rake assistant:guide_gaps`.
#
#   reason: no_guide    → search_guides no encontró ninguna guía
#           not_covered → había guía pero no traía la respuesta (Dali llamó report_gap)
#           thumbs_down → el usuario marcó 👎 la respuesta
#   status: pending | resolved | discarded
#
# AssistantGuideGap.record!(...) junta la misma pregunta pendiente (misma cuenta,
# mismo texto normalizado y motivo) y le suma una vez más.
class AssistantGuideGap < ApplicationRecord
  REASONS = %w[no_guide not_covered thumbs_down].freeze
  STATUSES = %w[pending resolved discarded].freeze
  MAX_QUESTION = 1000
  MAX_ANSWER = 2000

  belongs_to :account
  belongs_to :user, optional: true

  validates :question, :normalized, presence: true
  validates :reason, inclusion: { in: REASONS }
  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: 'pending') }
  scope :by_relevance, -> { order(occurrences: :desc, last_asked_at: :desc) }

  # details: user:, answer:, page:, guide_key: (todos opcionales)
  def self.record!(account:, question:, reason:, **details)
    text = question.to_s.squish.first(MAX_QUESTION)
    return if text.blank?

    normalized = Assistant::Guides.normalize(text).first(255)
    attrs = detail_attrs(details)
    gap = pending.find_by(account_id: account.id, normalized: normalized, reason: reason)
    return gap.tap { gap.update!(attrs.merge(occurrences: gap.occurrences + 1)) } if gap

    create!(attrs.merge(account: account, question: text, normalized: normalized, reason: reason))
  rescue StandardError => e
    Rails.logger.error("[Assistant] no se pudo registrar la pregunta sin respuesta: #{e.message}")
    nil
  end

  def self.detail_attrs(details)
    { user: details[:user], last_asked_at: Time.current, page: details[:page].presence,
      guide_key: details[:guide_key].presence, answer: details[:answer].to_s.first(MAX_ANSWER).presence }.compact
  end

  def resolve!(note = nil)
    update!(status: 'resolved', resolution_note: note.presence)
  end

  def discard!(note = nil)
    update!(status: 'discarded', resolution_note: note.presence)
  end
end
