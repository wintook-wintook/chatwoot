class CalendarAlertJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    UserCalendarIntegration.where(alert_enabled: true).find_each do |integration|
      process_integration(integration)
    rescue StandardError => e
      Rails.logger.error "CalendarAlertJob error for user #{integration.user_id}: #{e.message}"
    end
  end

  private

  def process_integration(integration)
    service = GoogleCalendarService.new(integration)
    upcoming = service.list_events(
      time_min: Time.current,
      time_max: Time.current + integration.alert_minutes_before.minutes + 1.minute
    )

    upcoming.each do |event|
      next if alert_already_sent?(integration, event['id'])

      send_notification(integration, event)
      mark_alert_sent(integration, event['id'])
    end
  end

  def send_notification(integration, event)
    Notification.create!(
      account: integration.account,
      user: integration.user,
      notification_type: :calendar_event_reminder,
      primary_actor: integration,
      meta: {
        event_id: event['id'],
        event_summary: event['summary'],
        minutes_before: integration.alert_minutes_before
      }
    )
  end

  def alert_already_sent?(integration, event_id)
    ::Redis::Alfred.get(redis_key(integration, event_id)).present?
  end

  def mark_alert_sent(integration, event_id)
    ::Redis::Alfred.setex(redis_key(integration, event_id), true, 1.hour)
  end

  def redis_key(integration, event_id)
    "cal_alert::#{integration.id}::#{event_id}"
  end
end
