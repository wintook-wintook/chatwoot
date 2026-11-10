# frozen_string_literal: true

# Cancelar tareas y tareas agendadas con motivo.
#   task_outcomes.purpose: report (resultado del reporte de cierre, como hoy) | cancel (motivo
#     de cancelación). Un solo catálogo editable en Catálogos › Resultados de tareas.
#   case_meetings.cancel_reason: el motivo de la cita cancelada (las tareas ya tienen el suyo).
class AddCancelReasons < ActiveRecord::Migration[7.0]
  def change
    add_column :task_outcomes, :purpose, :integer, null: false, default: 0
    add_column :case_meetings, :cancel_reason, :string
  end
end
