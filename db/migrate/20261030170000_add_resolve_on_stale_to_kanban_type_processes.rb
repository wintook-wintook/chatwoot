# Embudo de contactos — al descartar por días sin respuesta, resolver también la
# conversación (en silencio). Los tableros que ya existen quedan en false.
class AddResolveOnStaleToKanbanTypeProcesses < ActiveRecord::Migration[7.0]
  def change
    add_column :kanban_type_processes, :resolve_on_stale, :boolean, default: false, null: false
  end
end
