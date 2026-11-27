# frozen_string_literal: true

# Campaña con Vendedor IA (Motor 2.0) — la revisión justo antes de mandar CADA toque (no solo el primero, que ya
# acomoda TrackingCampaigns::Enroll). ContactTrackingJob la llama por Motor2::CampaignSendHook:
#
#   se dio de baja                         → se cancela (ya no le llega nada)
#   la campaña terminó o pasó su fin        → se cancela
#   una persona le escribió después del     → se pausa: ya lo atiende alguien
#     último mensaje del agente
#   fuera de horario (horario de la bandeja → se corre a la siguiente hora en que se puede (sin horario en la bandeja,
#     o días hábiles)                         de QUIET_START a QUIET_END de lunes a viernes, en la zona de la bandeja)
#   llegó al tope de envíos del día         → al día siguiente (el tope cuenta TODOS los toques, no solo los primeros)
#   otra campaña 2.0 le escribió hace menos → 24 h después de ese mensaje (máximo un mensaje de campañas al día por
#     de FREQUENCY                            contacto, como Klaviyo y el tope de marketing de WhatsApp)
#
# En «Prueba real» solo cuentan la baja, el fin y la persona: los toques salen cada pocos minutos.
#
#   TrackingCampaigns::SendGate.new(tracking).call → nil (mandar) | { action: :cancel | :pause | :wait, at:, reason: }
class TrackingCampaigns::SendGate
  FREQUENCY = 24.hours
  QUIET_START = 9
  QUIET_END = 19
  MIN_WAIT = 1.minute

  def initialize(tracking, now: Time.current)
    @tracking = tracking
    @campaign = tracking.tracking_campaign
    @now = now
  end

  def call
    return nil unless @campaign&.motor2?

    stop_reason || pause_reason || (@campaign.test_run? ? nil : wait)
  end

  # Aplica lo que decidió #call (dentro del lock de ContactTrackingJob). true si el toque NO debe salir.
  # El job ya marcó last_attempt_at = ahora; como el toque no salió, se regresa al de antes.
  def self.hold!(tracking, decision, previous_attempt_at: nil)
    case decision[:action]
    when :wait then return reschedule(tracking, decision, previous_attempt_at)
    when :cancel then attrs = { status: 'cancelled', outcome: decision[:reason] }
    when :pause then attrs = { status: 'paused', paused_at: Time.current }
    end
    tracking.update_columns(attrs.merge(last_attempt_at: previous_attempt_at, updated_at: Time.current)) # rubocop:disable Rails/SkipsModelValidations
    true
  end

  def self.reschedule(tracking, decision, previous_attempt_at)
    state = tracking.motor2_state.to_h.merge('send_wait' => decision[:reason].to_s)
    tracking.update_columns(status: 'scheduled', scheduled_for: decision[:at], last_attempt_at: previous_attempt_at, # rubocop:disable Rails/SkipsModelValidations
                            motor2_state: state, updated_at: Time.current)
    ContactTrackingJob.set(wait_until: decision[:at]).perform_later(tracking.id) unless TrackingDispatch.enabled_for?(tracking.account_id)
    true
  end

  private

  def stop_reason
    return { action: :cancel, reason: 'opted_out' } if @tracking.contact&.opted_out?
    return { action: :cancel, reason: 'campaign_finished' } if @campaign.status == 'finished'
    return { action: :cancel, reason: 'campaign_ended' } if @campaign.ends_at && @campaign.ends_at <= @now

    nil
  end

  def pause_reason
    person_wrote? ? { action: :pause, reason: 'person_wrote' } : nil
  end

  # Una persona del equipo escribió en la conversación después del último mensaje del agente.
  def person_wrote?
    conversation = @tracking.conversation
    return false unless conversation

    since = conversation.messages.where("#{AiFollowUp.message_attr_sql('ai_agent')} = 'true'").maximum(:created_at) || @tracking.created_at
    conversation.messages.where(message_type: :outgoing, private: false, sender_type: 'User').where('created_at > ?', since)
                .where("COALESCE(#{AiFollowUp.message_attr_sql('ai_agent')}, '') <> 'true'").exists?
  end

  def wait
    candidates = [[open_at(@now), 'hours'], [cap_at, 'daily_cap'], [frequency_at, 'frequency']].select { |at, _| at && at > @now + MIN_WAIT }
    at, reason = candidates.max_by(&:first)
    return nil unless at

    { action: :wait, at: open_at(at), reason: reason }
  end

  def schedule = @schedule ||= TrackingCampaigns::Schedule.new(@campaign)

  def zone = schedule.zone_name

  # Horario de la bandeja (o días hábiles); sin horario en la bandeja, además nunca de noche.
  def open_at(time)
    time = schedule.next_send_time(time) if @campaign.respect_working_hours
    return time if time.nil? || !@campaign.respect_working_hours || @campaign.inbox&.working_hours_enabled?

    quiet(time.in_time_zone(zone))
  end

  def quiet(local)
    local = local.change(hour: QUIET_START) if local.hour < QUIET_START
    local = (local + 1.day).change(hour: QUIET_START) if local.hour >= QUIET_END
    local += 1.day while local.saturday? || local.sunday?
    local
  end

  # El tope del día cuenta los toques de cualquier número (no solo los primeros, que reparte Enroll).
  def cap_at
    cap = @campaign.daily_send_cap(@now.in_time_zone(zone))
    return nil unless cap

    today = @now.in_time_zone(zone).all_day
    sent = @campaign.contact_trackings.where(last_attempt_at: today).where.not(id: @tracking.id).count
    sent >= cap ? today.last + 1.second : nil
  end

  # Otra campaña 2.0 (de verdad) le escribió hace menos de FREQUENCY.
  def frequency_at
    last = ContactTracking.where(contact_id: @tracking.contact_id, account_id: @tracking.account_id)
                          .where.not(id: @tracking.id).where.not(tracking_campaign_id: [nil, @campaign.id])
                          .joins(:tracking_campaign).where(tracking_campaigns: { engine: '2', test_of_id: nil })
                          .where('contact_trackings.last_attempt_at > ?', @now - FREQUENCY).maximum(:last_attempt_at)
    last && (last + FREQUENCY)
  end
end
