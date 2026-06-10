# frozen_string_literal: true

# == Schema Information
#
# Table name: case_sla_policies
#
#  id                         :bigint           not null, primary key
#  active                     :boolean          default(TRUE), not null
#  business_hours_only        :boolean          default(FALSE), not null
#  first_response_time_target :integer
#  priority                   :integer          not null
#  resolution_time_target     :integer
#  ticket_kind                :integer
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  account_id                 :bigint           not null
#  case_type_id               :bigint
#
# Indexes
#
#  index_case_sla_policies_on_account_id_and_priority  (account_id,priority)
#  index_case_sla_policies_unique_scope                (account_id,case_type_id,ticket_kind,priority) UNIQUE
#

# @tickets_cases 2I — política SLA configurable. La resolución elige la más específica
# (coincide case_type y ticket_kind) y cae al hash CaseTicket::SLA_BY_PRIORITY si no hay ninguna.
class CaseSlaPolicy < ApplicationRecord
  belongs_to :account
  belongs_to :case_type, optional: true

  enum priority:    { low: 0, medium: 1, high: 2, urgent: 3 }, _prefix: :priority
  enum ticket_kind: { incident: 0, service_request: 1, problem: 2, change: 3, query: 4 }, _prefix: :kind

  validates :priority, presence: true
  # El índice único de BD no dedup­lica cuando case_type_id/ticket_kind son NULL
  # (en Postgres NULL != NULL). Esta validación a nivel de modelo sí trata el nil como IS NULL.
  validates :priority, uniqueness: {
    scope: %i[account_id case_type_id ticket_kind],
    message: 'ya tiene una política para ese ámbito (prioridad + tipo + naturaleza)'
  }
  validate :at_least_one_target

  scope :active_policies, -> { where(active: true) }

  # SLA sugeridos del documento (minutos). Semilla por cuenta.
  DEFAULTS = [
    { priority: 'urgent', first_response_time_target: 15,  resolution_time_target: 240 },
    { priority: 'high',   first_response_time_target: 30,  resolution_time_target: 480 },
    { priority: 'medium', first_response_time_target: 240, resolution_time_target: 1440 },
    { priority: 'low',    first_response_time_target: 480, resolution_time_target: 4320 }
  ].freeze

  def self.ensure_defaults_for(account)
    return if account.case_sla_policies.exists?

    DEFAULTS.each do |attrs|
      account.case_sla_policies.create!(attrs.merge(business_hours_only: false, active: true))
    end
  end

  # Devuelve la política más específica activa para un ticket, o nil (→ fallback al hash).
  def self.resolve_for(ticket)
    active_policies
      .where(account_id: ticket.account_id, priority: priorities[ticket.priority])
      .where('case_type_id IS NULL OR case_type_id = ?', ticket.case_type_id)
      .where('ticket_kind IS NULL OR ticket_kind = ?', ticket_kinds[ticket.ticket_kind])
      .max_by { |p| (p.case_type_id ? 2 : 0) + (p.ticket_kind ? 1 : 0) }
  end

  private

  def at_least_one_target
    if first_response_time_target.blank? && resolution_time_target.blank?
      errors.add(:base, 'Define al menos un objetivo de tiempo (1ª respuesta o resolución)')
    end
  end
end
