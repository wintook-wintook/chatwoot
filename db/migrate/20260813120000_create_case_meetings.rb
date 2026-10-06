# frozen_string_literal: true

# @tickets_cases F0 — Reuniones y series de reuniones del ticket (ver
# docs/tickets_reuniones_plan.md §3).
#
# Dos tablas:
#   * `case_meeting_series` — la SERIE: guarda el RRULE y el id del evento
#     recurrente MAESTRO de Google. Folio S01 por ticket.
#   * `case_meetings` — la reunión concreta (ocurrencia o suelta). Folio R001 por
#     ticket. Con `case_meeting_series_id` NULL es una reunión suelta.
#
# La reunión puede colgar del ticket o de una TAREA del ticket (`case_task_id`),
# igual que las notas internas: al borrar la tarea la reunión NO se pierde,
# vuelve a ser del ticket (:nullify).
class CreateCaseMeetings < ActiveRecord::Migration[7.0]
  def change
    # La serie va primero: `case_meetings` la referencia.
    create_series_table
    add_series_indexes_and_keys
    create_meetings_table
    add_meetings_indexes_and_keys
  end

  private

  def create_series_table
    create_table :case_meeting_series do |t|
      t.bigint   :account_id,     null: false
      t.bigint   :case_ticket_id, null: false
      # case_task_id se hereda a las ocurrencias; organizer_id es el dueño del
      # calendario donde vive el evento maestro.
      t.bigint   :case_task_id, :organizer_id, :cancelled_by_id
      t.integer  :sequence # consecutivo por ticket → folio S01
      t.string   :title, null: false
      t.text     :description, :sync_error
      # recurrence_rule = el RRULE crudo: "RRULE:FREQ=WEEKLY;BYDAY=TU;COUNT=8".
      # google_event_id = el evento MAESTRO recurrente.
      t.string   :recurrence_rule, :time_zone, :google_event_id, :google_calendar_id
      # Piezas sueltas del RRULE, para re-renderizar el formulario sin parsearlo.
      t.integer  :freq,     null: false, default: 1 # weekly
      t.integer  :interval, null: false, default: 1 # "cada N semanas"
      t.jsonb    :by_day,   null: false, default: [] # ["TU","TH"]
      t.datetime :starts_at, null: false # primera ocurrencia: define hora y duración
      t.datetime :ends_at,   null: false
      # until_at (fin por fecha) y count (fin por número) son excluyentes entre sí.
      t.datetime :until_at, :cancelled_at
      t.integer  :count
      t.integer  :sync_status, null: false, default: 0
      t.timestamps
    end
  end

  def add_series_indexes_and_keys
    add_index :case_meeting_series, %i[case_ticket_id sequence],
              name: 'index_case_meeting_series_on_ticket_and_sequence'
    add_index :case_meeting_series, :account_id
    add_index :case_meeting_series, :case_task_id
    add_index :case_meeting_series, :google_event_id

    add_foreign_key :case_meeting_series, :accounts,     column: :account_id
    add_foreign_key :case_meeting_series, :case_tickets, column: :case_ticket_id
    add_foreign_key :case_meeting_series, :case_tasks,   column: :case_task_id,    on_delete: :nullify
    add_foreign_key :case_meeting_series, :users,        column: :organizer_id,    on_delete: :nullify
    add_foreign_key :case_meeting_series, :users,        column: :cancelled_by_id, on_delete: :nullify
  end

  def create_meetings_table
    create_table :case_meetings do |t|
      t.bigint   :account_id,     null: false
      t.bigint   :case_ticket_id, null: false
      # case_meeting_series_id NULL = reunión suelta. La reunión sobrevive al
      # borrado de la tarea y a la desconexión del organizador.
      t.bigint   :case_task_id, :case_meeting_series_id, :organizer_id
      t.bigint   :cancelled_by_id, :held_by_id
      t.integer  :sequence # consecutivo por ticket → folio R001
      t.string   :title, null: false
      t.text     :description, :sync_error # sync_error: último error de la API, se muestra en la fila
      t.datetime :starts_at, null: false # siempre UTC en BD
      t.datetime :ends_at,   null: false
      # time_zone: IANA de la cuenta al crear. meeting_url: liga de Meet de Google.
      # google_event_id: id de la INSTANCIA (no del maestro).
      t.string   :time_zone, :location, :meeting_url, :google_event_id, :google_calendar_id
      t.integer  :status,          null: false, default: 0
      t.integer  :sync_status,     null: false, default: 0
      t.jsonb    :attendee_emails, null: false, default: [] # snapshot de a quién se invitó
      t.boolean  :notify_client,   null: false, default: true
      # reconciled_at: última relectura desde Google (throttle §5). Las firmas
      # cancelled_*/held_* se derivan del cambio de estado, nunca del cliente.
      t.datetime :reconciled_at, :cancelled_at, :held_at
      t.timestamps
    end
  end

  def add_meetings_indexes_and_keys
    add_index :case_meetings, %i[case_ticket_id starts_at]
    add_index :case_meetings, %i[case_ticket_id sequence]
    add_index :case_meetings, :case_task_id
    add_index :case_meetings, :case_meeting_series_id, name: 'index_case_meetings_on_series_id'
    add_index :case_meetings, %i[account_id starts_at] # futura bandeja de reuniones (F8)
    add_index :case_meetings, :google_event_id

    add_foreign_key :case_meetings, :accounts,            column: :account_id
    add_foreign_key :case_meetings, :case_tickets,        column: :case_ticket_id
    add_foreign_key :case_meetings, :case_tasks,          column: :case_task_id, on_delete: :nullify
    add_foreign_key :case_meetings, :case_meeting_series, column: :case_meeting_series_id, on_delete: :cascade
    add_foreign_key :case_meetings, :users,               column: :organizer_id,    on_delete: :nullify
    add_foreign_key :case_meetings, :users,               column: :cancelled_by_id, on_delete: :nullify
    add_foreign_key :case_meetings, :users,               column: :held_by_id,      on_delete: :nullify
  end
end
