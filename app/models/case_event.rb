# frozen_string_literal: true

# == Schema Information
#
# Table name: case_events
#
#  id             :bigint           not null, primary key
#  event_type     :integer          not null
#  origin         :integer          not null
#  payload        :jsonb            not null
#  created_at     :datetime         not null
#  account_id     :bigint           not null
#  actor_id       :bigint
#  case_ticket_id :bigint           not null
#
# Indexes
#
#  index_case_events_on_account_id_and_created_at      (account_id,created_at)
#  index_case_events_on_case_ticket_id_and_event_type  (case_ticket_id,event_type)
#  index_case_events_on_payload                        (payload) USING gin
#

class CaseEvent < ApplicationRecord
  belongs_to :case_ticket
  belongs_to :account
  belongs_to :actor, class_name: 'User', optional: true

  enum event_type: {
    ticket_created:     0,
    ticket_classified:  1,
    status_changed:     2,
    assigned:           3,
    reassigned:         4,
    escalated:          5,
    message_received:   6,
    message_sent:       7,
    tracking_triggered: 8,
    tracking_paused:    9,
    resolved:           10,
    reopened:           11,
    closed:             12,
    sla_at_risk:        13,
    sla_overdue:        14,
    error_detected:     15,
    internal_note:      16,
    in_diagnosis:       17,
    validating:         18,
    related:            19,
    change_approved:    20,
    change_rejected:    21,
    problem_propagated: 22,
    article_generated:  23,
    ai_classified:      24,
    ai_suggested:       25,
    ai_followup:        26,
    priority_changed:   27,
    due_date_changed:   28
  }

  enum origin: { bot: 0, agent: 1, system: 2 }

  validates :event_type, presence: true
  validates :origin,     presence: true
end
