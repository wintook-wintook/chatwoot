class Webhooks::InstagramEventsJob < MutexApplicationJob
  queue_as :default
  retry_on LockAcquisitionError, wait: 1.second, attempts: 8

  # @return [Array] We will support further events like reaction or seen in future
  SUPPORTED_EVENTS = [:message, :read].freeze

  def perform(entries)
    @entries = entries

    key = format(::Redis::Alfred::IG_MESSAGE_MUTEX, sender_id: sender_id, ig_account_id: ig_account_id)
    with_lock(key) do
      process_entries(entries)
    end
  end

  # @see https://developers.facebook.com/docs/messenger-platform/instagram/features/webhook
  def process_entries(entries)
    entries.each do |entry|
      entry = entry.with_indifferent_access
      next process_test_event(entry) if test_event?(entry)

      messages(entry).each do |messaging|
        send(@event_name, messaging) if event_name(messaging)
      end
    end
  end

  private

  # Los eventos reales llegan en `messaging`; los de prueba del panel de Meta vienen
  # envueltos en `changes`. No es una incoherencia de Meta: mantiene compatibilidad con
  # los dos formatos, el de Instagram Direct y el de Página de Facebook.
  def test_event?(entry)
    entry[:changes].present?
  end

  def process_test_event(entry)
    messaging = entry[:changes].first&.dig(:value)
    return if messaging.blank?

    ::Instagram::TestEventService.new(messaging).perform
  end

  def ig_account_id
    @entries&.first&.dig(:id)
  end

  def sender_id
    @entries&.dig(0, :messaging, 0, :sender, :id)
  end

  def event_name(messaging)
    @event_name ||= SUPPORTED_EVENTS.find { |key| messaging.key?(key) }
  end

  def message(messaging)
    # Por la ruta legacy el evento de prueba llega con forma de mensaje normal, con los
    # ids de mentira: se atiende igual, y para un mensaje real esto es comparar dos ids.
    return if ::Instagram::TestEventService.new(messaging).perform

    ::Instagram::MessageText.new(messaging).perform
  end

  def read(messaging)
    ::Instagram::ReadStatusService.new(params: messaging).perform
  end

  def messages(entry)
    (entry[:messaging].presence || entry[:standby] || [])
  end
end
