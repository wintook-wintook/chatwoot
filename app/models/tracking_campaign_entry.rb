# frozen_string_literal: true

# == Schema Information
#
# Table name: tracking_campaign_entries
#
#  id                   :bigint           not null, primary key
#  reason               :string
#  source               :string           not null
#  status               :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  account_id           :bigint           not null
#  automation_rule_id   :bigint
#  contact_id           :bigint           not null
#  contact_tracking_id  :bigint
#  conversation_id      :bigint
#  tracking_campaign_id :bigint           not null
#
# Indexes
#
#  index_tracking_campaign_entries_by_status                (tracking_campaign_id,status)
#  index_tracking_campaign_entries_on_account_id            (account_id)
#  index_tracking_campaign_entries_on_automation_rule_id    (automation_rule_id)
#  index_tracking_campaign_entries_on_contact_id            (contact_id)
#  index_tracking_campaign_entries_on_contact_tracking_id   (contact_tracking_id)
#  index_tracking_campaign_entries_on_conversation_id       (conversation_id)
#  index_tracking_campaign_entries_on_tracking_campaign_id  (tracking_campaign_id)
#  index_tracking_campaign_entries_one_enrollment           (tracking_campaign_id,contact_id) UNIQUE WHERE ((status)::text = 'enrolled'::text)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#  fk_rails_...  (automation_rule_id => automation_rules.id) ON DELETE => nullify
#  fk_rails_...  (contact_id => contacts.id) ON DELETE => cascade
#  fk_rails_...  (contact_tracking_id => contact_trackings.id) ON DELETE => nullify
#  fk_rails_...  (conversation_id => conversations.id) ON DELETE => nullify
#  fk_rails_...  (tracking_campaign_id => tracking_campaigns.id) ON DELETE => cascade
#
# ================================================================================
# proyecto@automatizacion_campanas — UNA INSCRIPCIÓN A UNA CAMPAÑA
# ================================================================================
# Plan: docs/automatizacion_campanas_plan.md (§5.2). Cada intento de meter a un contacto
# en una TrackingCampaign, entre o no, por lote o por una automatización.
#
#   enrolled  entró: `contact_tracking` es el seguimiento del Agente IA que se le creó
#   skipped   no entró: `reason` dice por qué
#
# Un contacto se inscribe UNA vez por campaña (índice único parcial sobre los inscritos);
# los omitidos se repiten y cuentan, para que la campaña pueda decir cuántos intentos
# hubo y por qué no entraron.
# ================================================================================
class TrackingCampaignEntry < ApplicationRecord
  SOURCES = %w[batch automation].freeze
  STATUSES = %w[enrolled skipped].freeze
  REASONS = %w[campaign_closed already_enrolled active_tracking outside_window daily_cap].freeze

  belongs_to :account
  belongs_to :tracking_campaign
  belongs_to :contact
  belongs_to :conversation, optional: true
  belongs_to :automation_rule, optional: true
  belongs_to :contact_tracking, optional: true

  validates :source, inclusion: { in: SOURCES }
  validates :status, inclusion: { in: STATUSES }
  validates :reason, inclusion: { in: REASONS }, if: :skipped?
  validates :reason, absence: true, if: :enrolled?

  scope :enrolled, -> { where(status: 'enrolled') }
  scope :skipped, -> { where(status: 'skipped') }

  def enrolled?
    status == 'enrolled'
  end

  def skipped?
    status == 'skipped'
  end
end
