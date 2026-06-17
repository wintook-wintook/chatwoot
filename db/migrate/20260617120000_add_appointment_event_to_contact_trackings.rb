# frozen_string_literal: true

# proyecto@bot_seguimiento_calendar — guardar la referencia del evento de Google
# Calendar creado al agendar una cita, para poder MOVER o CANCELAR esa cita después.
# Hasta ahora `create_event` devolvía el evento pero su `id` se descartaba, así que
# no había forma de identificar qué evento actualizar/borrar.
#   - appointment_event_id:    id del evento en Google Calendar
#   - appointment_calendar_id: UserCalendarIntegration usada para crearlo (sobre la
#                              que hay que llamar update_event / delete_event)
class AddAppointmentEventToContactTrackings < ActiveRecord::Migration[7.0]
  def change
    add_column :contact_trackings, :appointment_event_id, :string
    add_column :contact_trackings, :appointment_calendar_id, :bigint
  end
end
