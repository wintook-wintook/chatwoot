# frozen_string_literal: true

# == Schema Information
#
# Table name: ready_agents
#
#  id            :bigint           not null, primary key
#  enabled       :boolean          default(FALSE), not null
#  inbox_ids     :bigint           default([]), not null, is an Array
#  kind          :string           not null
#  name          :string           not null
#  settings      :jsonb            not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :bigint           not null
#  created_by_id :bigint
#
# Indexes
#
#  index_ready_agents_on_account_id     (account_id)
#  index_ready_agents_on_created_by_id  (created_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (created_by_id => users.id)
#
# Agente listo: un puesto empaquetado (el de «Atención a prospectos» por ahora) que la empresa
# activa con su nombre, sus bandejas y lo que contesta en el activador. Atiende solo: no usa
# automatizaciones. Un agente listo por bandeja.
#
# settings (lo que se contesta al activarlo):
#   objective        handoff (pasarlo a una persona) | opportunity (crear la oportunidad) | collect (solo datos)
#   questions        qué le pregunta para calificarlo
#   qualified_when   cuándo está calificado
#   discard_when     cuándo se descarta
#   tone             cercano | formal | directo
#   instructions     indicaciones adicionales
#   handoff_user_id / handoff_team_id   a quién pasa al prospecto calificado (o cuando pide una persona)
#   client_user_id / client_team_id     a quién pasa a quien ya es cliente si no tiene responsable fijo
#   only_prospects   true: a quien ya es cliente no lo atiende, lo pasa a una persona
class ReadyAgent < ApplicationRecord
  KINDS = %w[prospects].freeze
  OBJECTIVES = %w[handoff opportunity collect].freeze
  TONES = %w[cercano formal directo].freeze

  belongs_to :account
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :sessions, class_name: 'ReadyAgentSession', dependent: :destroy

  before_validation :normalize

  validates :name, presence: true, length: { maximum: 60 }
  validates :kind, inclusion: { in: KINDS }
  validate :one_agent_per_inbox
  validate :inboxes_in_account

  scope :enabled, -> { where(enabled: true) }

  # El agente listo prendido de una bandeja (uno por bandeja).
  def self.for_inbox(inbox_id)
    return if inbox_id.blank?

    enabled.where(':id = ANY(inbox_ids)', id: inbox_id.to_i).first
  end

  def setting(key) = settings.to_h[key.to_s]

  def objective = OBJECTIVES.include?(setting(:objective)) ? setting(:objective) : 'handoff'
  def tone = TONES.include?(setting(:tone)) ? setting(:tone) : 'cercano'
  def only_prospects? = setting(:only_prospects) != false

  def inboxes = account.inboxes.where(id: inbox_ids)

  private

  def normalize
    self.name = name.to_s.squish
    self.inbox_ids = Array(inbox_ids).compact_blank.map(&:to_i).uniq
    self.settings = settings.to_h.stringify_keys
  end

  def one_agent_per_inbox
    return unless enabled? && inbox_ids.any?

    taken = account.ready_agents.enabled.where.not(id: id).where('inbox_ids && ARRAY[?]::bigint[]', inbox_ids)
    names = taken.pluck(:name)
    errors.add(:inbox_ids, "ya tienen agente listo (#{names.join(', ')}): una bandeja solo puede tener uno") if names.any?
  end

  def inboxes_in_account
    errors.add(:inbox_ids, 'no son de la cuenta') if inbox_ids.any? && account.inboxes.where(id: inbox_ids).count != inbox_ids.size
  end
end
