# proyecto@solicitudes (pieza 5, F0): la tarea agendada de un servicio se aparta sin quedar en
# firme hasta que el cliente confirma (o paga).
class AddTentativeToCaseMeetings < ActiveRecord::Migration[7.0]
  def change
    add_column :case_meetings, :tentative, :boolean, default: false, null: false
  end
end
