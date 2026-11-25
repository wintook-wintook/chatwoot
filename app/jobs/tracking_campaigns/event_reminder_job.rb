# frozen_string_literal: true

# Campaña con IA · Invitar — cada 10 min: a los que confirmaron, el recordatorio de un día antes y de una hora
# antes del evento (TrackingCampaigns::EventReminders). Solo campañas 2.0 de Invitar con evento por venir.
class TrackingCampaigns::EventReminderJob < ApplicationJob
  queue_as :scheduled_jobs

  ACTIVE = %w[running finished].freeze

  def perform
    TrackingCampaign.where(engine: '2', status: ACTIVE).where("brief ->> 'kind' = 'invite'")
                    .joins(:event).where(events: { starts_at: Time.current..25.hours.from_now })
                    .find_each { |campaign| TrackingCampaigns::EventReminders.run(campaign) }
  end
end
