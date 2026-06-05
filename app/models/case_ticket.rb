# frozen_string_literal: true

# == Schema Information
#
# Table name: case_tickets
#
#  id                         :bigint           not null, primary key
#  assignee_type              :integer          default("bot"), not null
#  closed_at                  :datetime
#  custom_attributes          :jsonb            not null
#  description                :text
#  first_response_at          :datetime
#  first_response_time_target :integer
#  folio                      :string
#  metadata                   :jsonb            not null
#  origin                     :integer          default("whatsapp"), not null
#  priority                   :integer          default("medium"), not null
#  resolution_time_target     :integer
#  resolved_at                :datetime
#  sla_status                 :integer          default("on_time"), not null
#  status                     :integer          default("open"), not null
#  title                      :string           not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  account_id                 :bigint           not null
#  assignee_id                :bigint
#  case_type_id               :bigint
#  contact_id                 :bigint           not null
#  contact_tracking_id        :bigint
#  conversation_id            :bigint
#  team_id                    :bigint
#
# Indexes
#
#  index_case_tickets_on_account_and_folio            (account_id,folio) UNIQUE WHERE (folio IS NOT NULL)
#  index_case_tickets_on_account_id_and_case_type_id  (account_id,case_type_id)
#  index_case_tickets_on_account_id_and_contact_id    (account_id,contact_id)
#  index_case_tickets_on_account_id_and_sla_status    (account_id,sla_status)
#  index_case_tickets_on_account_id_and_status        (account_id,status)
#  index_case_tickets_on_metadata                     (metadata) USING gin
#

class CaseTicket < ApplicationRecord
  VALID_TRANSITIONS = {
    'open'                => %w[classified cancelled],
    'classified'          => %w[in_progress cancelled],
    'in_progress'         => %w[waiting_on_customer waiting_on_internal escalated resolved cancelled],
    'waiting_on_customer' => %w[in_progress cancelled],
    'waiting_on_internal' => %w[in_progress cancelled],
    'escalated'           => %w[in_progress cancelled],
    'resolved'            => %w[closed in_progress],
    'closed'              => [],
    'cancelled'           => []
  }.freeze

  SLA_BY_PRIORITY = {
    'low'    => { first_response_time_target: 2880, resolution_time_target: 7200 },
    'medium' => { first_response_time_target: 480,  resolution_time_target: 2880 },
    'high'   => { first_response_time_target: 120,  resolution_time_target: 480  },
    'urgent' => { first_response_time_target: 30,   resolution_time_target: 120  }
  }.freeze

  belongs_to :account
  belongs_to :contact
  belongs_to :conversation,      optional: true
  belongs_to :contact_tracking,  optional: true
  belongs_to :assignee,          class_name: 'User', optional: true
  belongs_to :team,              optional: true
  belongs_to :case_type,         optional: true # @tickets_cases: tipo configurable por cuenta
  has_many   :case_events,       dependent: :destroy

  enum origin:       { whatsapp: 0, web: 1, email: 2, bot: 3, manual: 4 }
  enum priority:     { low: 0, medium: 1, high: 2, urgent: 3 }
  enum status:       { open: 0, classified: 1, in_progress: 2, waiting_on_customer: 3,
                       waiting_on_internal: 4, escalated: 5, resolved: 6, closed: 7, cancelled: 8 }
  enum assignee_type: { bot: 0, agent: 1, team: 2, system: 3 }, _prefix: :assignee
  enum sla_status:   { on_time: 0, at_risk: 1, overdue: 2 }

  validates :title,         presence: true, length: { maximum: 255 }
  validates :origin,        presence: true
  validates :priority,      presence: true
  validates :status,        presence: true
  validates :assignee_type, presence: true
  validates :sla_status,    presence: true

  before_create :assign_sla_targets
  before_create :assign_folio # @tickets_cases
  after_create  :create_ticket_created_event

  def can_transition_to?(new_status)
    VALID_TRANSITIONS[status].include?(new_status.to_s)
  end

  def transition!(new_status, actor: nil, reason: nil)
    raise "Transición inválida: #{status} → #{new_status}" unless can_transition_to?(new_status)

    old_status  = status
    attrs       = { status: new_status }
    attrs[:resolved_at] = Time.current if new_status.to_s == 'resolved'
    attrs[:closed_at]   = Time.current if new_status.to_s == 'closed'

    update!(attrs)

    case_events.create!(
      account:    account,
      event_type: event_type_for_transition(new_status),
      origin:     actor ? :agent : :system,
      actor:      actor,
      payload:    { from: old_status, to: new_status.to_s, reason: reason }.compact
    )
  end

  def calculate_sla_status
    return :on_time if resolved? || closed? || cancelled?

    elapsed = ((Time.current - created_at) / 60).to_i
    target  = first_response_at.nil? ? first_response_time_target : resolution_time_target

    return :on_time if target.nil?

    ratio = elapsed.to_f / target
    return :overdue if ratio >= 1.0
    return :at_risk  if ratio >= 0.8

    :on_time
  end

  private

  def assign_sla_targets
    sla = SLA_BY_PRIORITY[priority.to_s]
    return unless sla

    self.first_response_time_target ||= sla[:first_response_time_target]
    self.resolution_time_target     ||= sla[:resolution_time_target]
  end

  # @tickets_cases: genera el folio según la plantilla de la cuenta (inmutable).
  def assign_folio
    return if folio.present?

    self.folio = Cases::FolioGeneratorService.new(self).generate
  rescue StandardError => e
    Rails.logger.error("[GestorTickets] folio error: #{e.message}")
  end

  def create_ticket_created_event
    case_events.create!(
      account:    account,
      event_type: :ticket_created,
      origin:     :system,
      payload:    { case_type: case_type&.name, priority: priority, origin: origin }
    )
  end

  def event_type_for_transition(new_status)
    case new_status.to_s
    when 'escalated'   then :escalated
    when 'resolved'    then :resolved
    when 'closed'      then :closed
    when 'in_progress' then resolved? ? :reopened : :status_changed
    else :status_changed
    end
  end
end
