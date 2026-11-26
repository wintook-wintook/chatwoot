# frozen_string_literal: true

# Campaña con IA · Invitar — los recordatorios del evento: un día antes y una hora antes, con su fecha, lugar y liga.
# Los manda TrackingCampaigns::EventReminderJob (cada 10 min); cómo se configuran: TrackingCampaigns::EventReminderSettings.
#
# A quién, según cada recordatorio:
#   confirmados        los de la campaña que lo lograron (outcome «Logrado: …»): su texto de recordatorio
#   no han contestado  (si el recordatorio es «confirmados y los que no han contestado») recibieron la invitación y
#                      nunca escribieron, sin baja ni rebote: su texto de última invitación. Si alguno todavía tenía
#                      toques, ya no salen (el evento es mañana). A quien le salió un toque hace menos de 12 h, se le
#                      espera un poco (un solo mensaje de la campaña por día).
#   nunca              los que dijeron que no, «no me escriban», se dieron de baja o ya atiende una persona (tienen outcome).
#
# Cada uno una sola vez por recordatorio (motor2_state['event_reminders']). En WhatsApp, pasadas 24 h desde su último
# mensaje solo sale con plantilla (Motor2::LateMessage); si no se puede y había confirmado, queda una nota en la
# conversación para que alguien le escriba.
module TrackingCampaigns::EventReminders
  Settings = TrackingCampaigns::EventReminderSettings
  KINDS = Settings::KINDS
  # Cuándo toca cada uno: [desde, hasta] antes de que empiece.
  WINDOWS = { 'day_before' => [24.hours, 3.hours], 'hour_before' => [1.hour, 0.minutes] }.freeze
  RECENT_TOUCH = 12.hours
  WAITING = %w[pending scheduled active paused].freeze

  module_function

  def sanitize(raw) = Settings.sanitize(raw)
  def check(campaign) = Settings.check(campaign)
  def config(campaign) = Settings.sanitize(campaign.brief.to_h['reminders'])

  # El que toca ahora (o nil): según cuánto falta para que empiece el evento.
  def due_kind(event, now = Time.current)
    return unless event&.starts_at

    left = event.starts_at - now
    KINDS.find { |kind| left <= WINDOWS[kind][0] && left > WINDOWS[kind][1] }
  end

  def run(campaign, now = Time.current)
    event = campaign.event
    kind = due_kind(event, now)
    config = config(campaign)
    return 0 unless kind && config[kind]

    sent = confirmed(campaign, kind).to_a.count { |tracking| deliver(campaign, event, tracking, kind, pending: false) }
    return sent unless Settings.pending_on?(config, kind)

    sent + not_answered(campaign, kind).to_a.count { |tracking| ready?(tracking) && deliver(campaign, event, tracking, kind, pending: true) }
  end

  # Sin baja y sin un toque reciente (se le espera: un solo mensaje de la campaña por día).
  def ready?(tracking)
    return false if tracking.contact&.opted_out?

    tracking.last_attempt_at.nil? || tracking.last_attempt_at <= RECENT_TOUCH.ago
  end

  def confirmed(campaign, kind) = not_reminded(campaign, kind).where('outcome LIKE ?', 'Logrado:%')

  # Recibieron la invitación, nunca escribieron y no tienen salida (baja, rebote, no esta vez, persona…).
  def not_answered(campaign, kind)
    not_reminded(campaign, kind).where(outcome: nil, prospect_exit: nil)
                                .where('contact_trackings.attempt_count > 0 OR contact_trackings.last_attempt_at IS NOT NULL')
                                .where.not('EXISTS (SELECT 1 FROM messages m WHERE m.conversation_id = contact_trackings.conversation_id ' \
                                           'AND m.message_type = 0 AND m.created_at > contact_trackings.created_at)')
  end

  def not_reminded(campaign, kind)
    campaign.contact_trackings.where.not("COALESCE(motor2_state -> 'event_reminders', '[]'::jsonb) ? :kind", kind: kind)
  end

  def deliver(campaign, event, tracking, kind, pending:)
    config = config(campaign)
    message = Motor2::LateMessage.deliver(tracking, text_for(campaign, event, tracking, kind, pending: pending),
                                          template: Settings.template_for(config, pending))
    not_sent(tracking, kind) if !message && !pending
    stop_touches(tracking, event) if message && pending
    true
  rescue StandardError => e
    Rails.logger.warn("[EventReminders] tracking #{tracking.id} #{kind}: #{e.class}: #{e.message}")
    false
  ensure
    mark(tracking, kind)
  end

  # Con la ventana abierta y «La IA lo escribe al momento»: para ese contacto (si falla, el texto fijo).
  def text_for(campaign, event, tracking, kind, pending:)
    if Settings.ai?(config(campaign), kind, pending) && tracking.conversation && Motor2::LateMessage.window_open?(tracking.conversation)
      written = TrackingCampaigns::ReminderWriter.new(campaign, kind: kind, pending: pending)
                                                 .for_contact(tracking, values(campaign, event, tracking, pending: pending))
    end
    written.presence || text(campaign, event, tracking, kind, pending: pending)
  end

  def text(campaign, event, tracking, kind, pending: false)
    fill(Settings.text_for(config(campaign), kind, pending), values(campaign, event, tracking, pending: pending)).squish
  end

  def values(campaign, event, tracking, pending: false)
    zone = tracking.inbox&.timezone.presence || 'America/Mexico_City'
    name = tracking.contact&.name.to_s.split.first
    { 'nombre' => (name if name.present? && !name.match?(/\A[+\d]/)).to_s, 'evento' => event.name.to_s,
      'cuando' => Motor2::Skills::Appointments.label(event.starts_at.in_time_zone(zone)),
      'lugar' => event.location.to_s, 'liga' => link(campaign, event, pending: pending).to_s }
  end

  # La liga: al que no ha contestado y se registra por su cuenta, la de registro; a los demás, la del evento.
  def link(campaign, event, pending: false)
    links = Array(campaign.brief.to_h['links'])
    registration = registration_link(campaign, links) if pending
    registration || event.meeting_url.presence || links.filter_map { |l| l['url'].presence }.first
  end

  def registration_link(campaign, links)
    return unless campaign.brief.to_h['offer_goal'] == 'external'

    links.find { |l| l['use'] == 'package' }&.dig('url').presence
  end

  def fill(text, values)
    text.gsub(/\{\{\s*(\w+)\s*\}\}/) { values.fetch(Regexp.last_match(1), '') }.gsub(/\s+([.,!?])/, '\1').gsub(/¡\s*!/, '¡')
  end

  # Ya recibió la última invitación: los toques que faltaban no salen (la campaña termina al empezar el evento).
  def stop_touches(tracking, event)
    return unless WAITING.include?(tracking.status) && event.starts_at

    tracking.update_columns(scheduled_for: event.starts_at + 1.minute, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  def mark(tracking, kind)
    state = tracking.reload.motor2_state.to_h
    done = (Array(state['event_reminders']) + [kind]).uniq
    tracking.update_columns(motor2_state: state.merge('event_reminders' => done), updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  def not_sent(tracking, kind)
    return unless tracking.conversation

    what = kind == 'day_before' ? 'el recordatorio de un día antes del evento' : 'el recordatorio de una hora antes del evento'
    Motor2::Delivery.note(tracking, tracking.conversation,
                          "⚠️ No se le pudo mandar #{what}: ya pasaron 24 h desde su último mensaje y la campaña no tiene " \
                          'plantilla para recordatorios. Escríbele tú o elige una plantilla en «Mensajes».')
  end
end
