# proyecto@hoja_buscar — pieza 4: un servicio apartado no es un servicio confirmado.
# nil = como siempre (la cita queda en firme al agendarse) · tentative · pending_payment · confirmed
class AddAppointmentStatusToContactTrackings < ActiveRecord::Migration[7.0]
  def change
    add_column :contact_trackings, :appointment_status, :string
  end
end
