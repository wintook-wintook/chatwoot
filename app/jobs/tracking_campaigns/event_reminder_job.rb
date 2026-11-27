# frozen_string_literal: true

# Campaña con IA — cada 10 min: Invitar, los recordatorios de un día antes y de una hora antes del evento
# (TrackingCampaigns::EventReminders); Ofrecer y Reactivar, el «Último aviso» antes de que termine la promoción
# (TrackingCampaigns::LastCall).
class TrackingCampaigns::EventReminderJob < ApplicationJob
  queue_as :scheduled_jobs

  ACTIVE = %w[running finished].freeze

  def perform
    TrackingCampaign.where(engine: '2', status: ACTIVE).where("brief ->> 'kind' = 'invite'")
                    .joins(:event).where(events: { starts_at: Time.current..25.hours.from_now })
                    .find_each { |campaign| TrackingCampaigns::EventReminders.run(campaign) }
    last_calls
  end

  # Con vigencia en los próximos dos días (LastCall decide si ya toca).
  def last_calls
    TrackingCampaign.where(engine: '2', status: 'running').where("brief ->> 'kind' IN (?)", TrackingCampaigns::LastCall::KINDS)
                    .where("brief ->> 'valid_until' BETWEEN ? AND ?", Date.current.iso8601, 2.days.from_now.to_date.iso8601)
                    .find_each { |campaign| TrackingCampaigns::LastCall.run(campaign) }
  end
end
