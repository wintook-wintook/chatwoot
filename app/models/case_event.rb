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
#  case_task_id   :bigint
#  case_ticket_id :bigint           not null
#
# Indexes
#
#  index_case_events_on_account_id_and_created_at      (account_id,created_at)
#  index_case_events_on_case_task_id                   (case_task_id)
#  index_case_events_on_case_ticket_id_and_event_type  (case_ticket_id,event_type)
#  index_case_events_on_payload                        (payload) USING gin
#
# Foreign Keys
#
#  fk_rails_...  (case_task_id => case_tasks.id) ON DELETE => nullify
#

class CaseEvent < ApplicationRecord
  belongs_to :case_ticket
  belongs_to :account
  belongs_to :actor, class_name: 'User', optional: true
  # @tickets_cases — una nota interna puede colgar de una tarea del ticket.
  # NULL = nota del ticket mismo (comportamiento por defecto).
  belongs_to :case_task, optional: true

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
    due_date_changed:   28,
    column_changed:     29, # @tickets_cases — movió de columna del Kanban (mismo estado)
    # @tickets_cases F0 — Reuniones. Al FINAL del enum, sin reordenar nada de arriba.
    meeting_scheduled:  30, # se agendó reunión o serie
    meeting_updated:    31, # se movió de fecha/hora
    meeting_cancelled:  32, # se canceló (una o toda la serie)
    meeting_held:       33, # se marcó realizada / no asistió
    # @tickets_cases — Plan-Clase-Comercial F1. Al FINAL, sin reordenar nada de arriba.
    case_class_changed: 34, # el caso pasó a otra clase (cambió su tipo, o la clase de su tipo)
    # @tickets_cases — Plan-Clase-Comercial F3. Al FINAL, sin reordenar nada de arriba.
    outcome_set:        35, # oportunidad cerrada como ganada/perdida/cancelada
    postponed:          36, # oportunidad pospuesta hasta una fecha
    resumed:            37, # oportunidad pospuesta que volvió a trabajarse
    amount_changed:     38, # cambiaron los datos comerciales (monto, moneda, cierre, probabilidad)
    # @tickets_cases — Plan-Clase-Orden-de-Trabajo F2a. Al FINAL, sin reordenar nada de arriba.
    work_order_changed: 39, # cambiaron los datos de la orden (dirección, horas, facturable)
    # @tickets_cases — Plan-Clase-Proyecto P1. Al FINAL, sin reordenar nada de arriba.
    project_changed:    40, # cambiaron los datos del proyecto (fechas, presupuesto, avance)
    # @tickets_cases — Plan-Metricas-Comercial. Al FINAL, sin reordenar nada de arriba.
    commitment_changed: 41, # el cliente se comprometió / movió la fecha / se quitó (payload.action)
    # @tickets_cases — ligar conversación. Al FINAL, sin reordenar nada de arriba.
    conversation_link:  42, # se ligó (o creó) la conversación del caso (payload.display_id, created)
    # Plan-Plantilla-Tareas-Etapa. Al FINAL, sin reordenar nada de arriba.
    stage_tasks_added:  43, # nacieron las tareas de la plantilla al entrar a una etapa
    stage_advanced:     44  # pasó sola a la siguiente etapa al terminar las obligatorias (payload.from/to)
  }

  enum origin: { bot: 0, agent: 1, system: 2 }

  validates :event_type, presence: true
  validates :origin,     presence: true
end
