# Visitas — una tarea agendada puede ser una visita al cliente: entra a «Mi ruta» y al
# despacho, y guarda cuándo salió, cuándo llegó y en qué coordenadas.
class AddVisitToCaseMeetings < ActiveRecord::Migration[7.0]
  def change
    add_column :case_meetings, :is_visit, :boolean, null: false, default: false
    add_column :case_meetings, :on_my_way_at, :datetime
    add_column :case_meetings, :arrived_at, :datetime
    add_column :case_meetings, :arrival_location, :jsonb, null: false, default: {}
    add_index :case_meetings, [:account_id, :starts_at], where: 'is_visit', name: 'index_case_meetings_on_visits'
  end
end
