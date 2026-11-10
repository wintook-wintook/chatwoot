# Plan-Eventos E3 — quien llega a un estado en un evento entra solo a las campañas
# CONTINUAS en curso de ese evento y estado (p. ej. al marcarlo «Asistió» le llega el
# agradecimiento). Por TrackingCampaigns::Enroll, el mismo camino que las automatizaciones.
class Events::CampaignEnrollJob < ApplicationJob
  queue_as :default

  def perform(attendee_id)
    attendee = EventAttendee.find_by(id: attendee_id)
    return unless attendee

    TrackingCampaign.where(account_id: attendee.account_id, mode: 'continuous', status: 'running',
                           event_id: attendee.event_id, event_status: attendee.status).find_each do |campaign|
      TrackingCampaigns::Enroll.new(campaign, attendee.contact, source: 'event').call
    end
  end
end
