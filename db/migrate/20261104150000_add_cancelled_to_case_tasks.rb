# Una tarea puede quedar cancelada cuando su caso se cierra: no se hizo ni cuenta como
# hecha, y regresa a pendiente si el caso se reabre. Las que ya estaban atoradas en un
# caso cerrado o cancelado se cancelan aquí, con el mismo motivo, y también sus tareas
# agendadas que ya pasaron.
class AddCancelledToCaseTasks < ActiveRecord::Migration[7.0]
  def up
    add_column :case_tasks, :cancelled_at, :datetime
    add_column :case_tasks, :cancel_reason, :string

    # Valores fijos: pendiente 0, cancelada 2; caso cerrado y cancelado por nombre del enum.
    closed = CaseTicket.statuses.values_at('closed', 'cancelled').join(',')
    execute <<~SQL.squish
      UPDATE case_tasks SET status = 2, cancelled_at = NOW(), cancel_reason = 'case_closed', updated_at = NOW()
      WHERE status = 0 AND case_ticket_id IN (SELECT id FROM case_tickets WHERE status IN (#{closed}))
    SQL
    # Tareas agendadas: las que ya pasaron sin marcarse. scheduled 0, rescheduled 4, cancelled 3.
    execute <<~SQL.squish
      UPDATE case_meetings SET status = 3, cancelled_at = NOW(), updated_at = NOW()
      WHERE status IN (0, 4) AND starts_at < NOW() AND case_ticket_id IN (SELECT id FROM case_tickets WHERE status IN (#{closed}))
    SQL
  end

  def down
    execute 'UPDATE case_tasks SET status = 0 WHERE status = 2'
    remove_column :case_tasks, :cancel_reason
    remove_column :case_tasks, :cancelled_at
  end
end
