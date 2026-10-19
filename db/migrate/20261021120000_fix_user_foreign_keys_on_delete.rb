# Llaves foráneas a users sin ON DELETE en tablas propias: cualquier fila que apuntara al usuario impedía
# borrarlo (DeleteObjectJob moría con PG::ForeignKeyViolation). User usa dependent: :destroy_async, que corre
# DESPUÉS del DELETE, así que la base es la que tiene que resolverlo.
#   - nullify: registros de la cuenta que deben sobrevivir al usuario (plantillas, campañas, tickets, tareas).
#   - cascade: datos personales del usuario que no sirven sin él. Los mensajes programados ya no se envían
#     sin usuario (ScheduledMessagesDeliveryJob lo exige).
class FixUserForeignKeysOnDelete < ActiveRecord::Migration[7.0]
  FOREIGN_KEYS = [
    [:case_tasks, :assignee_id, :nullify],
    [:case_tickets, :locked_by_id, :nullify],
    [:case_tickets, :requester_id, :nullify],
    [:tracking_campaigns, :user_id, :nullify],
    [:tracking_templates, :user_id, :nullify],
    [:command_sessions, :user_id, :cascade],
    [:scheduled_messages, :user_id, :cascade],
    [:user_calendar_integrations, :user_id, :cascade]
  ].freeze

  def up
    FOREIGN_KEYS.each { |table, column, on_delete| replace_foreign_key(table, column, on_delete) }
  end

  def down
    FOREIGN_KEYS.each { |table, column, _| replace_foreign_key(table, column, nil) }
  end

  private

  def replace_foreign_key(table, column, on_delete)
    return unless table_exists?(table)

    remove_foreign_key table, :users, column: column if foreign_key_exists?(table, :users, column: column)
    add_foreign_key table, :users, column: column, on_delete: on_delete
  end
end
