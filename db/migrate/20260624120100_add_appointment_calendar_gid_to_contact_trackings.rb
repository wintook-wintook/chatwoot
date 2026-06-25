# frozen_string_literal: true

# proyecto@bot_seguimiento_calendar
# Calendario de Google (gid) donde quedó creado el evento de la cita. Necesario para
# mover/cancelar cuando el bot agenda en un calendario distinto del principal (varias
# agendas marcadas como destino). nil → 'primary' (citas previas, comportamiento histórico).
class AddAppointmentCalendarGidToContactTrackings < ActiveRecord::Migration[7.0]
  def change
    add_column :contact_trackings, :appointment_calendar_gid, :string
  end
end
