# frozen_string_literal: true

# @tickets_cases — Consecutivo estable por ticket (estilo osTicket): las tareas
# se numeran T001, T002… y las notas internas N001, N002… El número se asigna al
# crear y NO se recicla al borrar (por eso se persiste, no se calcula por posición).
#
# - Tareas: columna real `sequence` en case_tasks (indexada junto al ticket).
# - Notas:  se guarda dentro del payload jsonb del case_event (evita tocar el
#   esquema de case_events, que almacena muchos tipos de evento).
class AddSequenceToCaseTasksAndNotes < ActiveRecord::Migration[7.0]
  def up
    add_column :case_tasks, :sequence, :integer
    add_index  :case_tasks, [:case_ticket_id, :sequence]

    # Backfill tareas: numeración por ticket en orden de creación (id asc).
    execute(<<~SQL.squish)
      UPDATE case_tasks t
      SET sequence = s.rn
      FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY case_ticket_id ORDER BY id) AS rn
        FROM case_tasks
      ) s
      WHERE t.id = s.id
    SQL

    # Backfill notas internas (event_type = 16): consecutivo por ticket en orden
    # cronológico, escrito dentro del payload.
    execute(<<~SQL.squish)
      UPDATE case_events e
      SET payload = e.payload || jsonb_build_object('sequence', s.rn)
      FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY case_ticket_id ORDER BY created_at, id) AS rn
        FROM case_events
        WHERE event_type = 16
      ) s
      WHERE e.id = s.id
    SQL
  end

  def down
    remove_index  :case_tasks, column: [:case_ticket_id, :sequence]
    remove_column :case_tasks, :sequence

    execute("UPDATE case_events SET payload = payload - 'sequence' WHERE event_type = 16")
  end
end
