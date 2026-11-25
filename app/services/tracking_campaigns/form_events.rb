# frozen_string_literal: true

# Campaña con IA — los eventos para el asistente: los de hoy en adelante (Invitar) y los de los últimos 90 días
# (audiencia «asistentes de un evento»: asistió, no se presentó). Hoy = desde las 00:00, hora de México.
module TrackingCampaigns::FormEvents
  ZONE = 'America/Mexico_City'
  LIMIT = 50

  module_function

  def today = Time.current.in_time_zone(ZONE).beginning_of_day

  # Los que empiezan de hoy en adelante y no están cerrados.
  def upcoming(account)
    account.events.where(closed_at: nil).where('starts_at >= ?', today).order(:starts_at).limit(LIMIT).map do |e|
      { id: e.id, name: e.name, starts_at: e.starts_at, capacity: e.capacity, location: e.location, meeting_url: e.meeting_url,
        description: e.description.to_s.first(600) }
    end
  end

  # Los de los últimos 90 días (los de hoy ya van en upcoming).
  def recent(account)
    account.events.where(starts_at: 90.days.ago...today).order(starts_at: :desc).limit(LIMIT)
           .map { |e| { id: e.id, name: e.name, starts_at: e.starts_at, capacity: e.capacity } }
  end
end
