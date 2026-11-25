# frozen_string_literal: true

# Campaña con IA · Invitar — los recordatorios a los que CONFIRMARON (o se registraron): un día antes y una hora
# antes del evento, con su fecha, lugar y liga. Los manda TrackingCampaigns::EventReminderJob (cada 10 min).
#
#   brief['reminders'] = { 'day_before' => true, 'hour_before' => true, 'day_text' => '', 'hour_text' => '',
#                          'template' => 'recordatorio_evento' }
#   Textos con {{nombre}} {{evento}} {{cuando}} {{lugar}} {{liga}}; vacíos = los de fábrica (DEFAULTS).
#
# A quién: los de la campaña que lo lograron (outcome «Logrado: …»). Cada uno una sola vez por recordatorio
# (motor2_state['event_reminders']). En WhatsApp, pasadas 24 h desde su último mensaje solo sale con la plantilla
# elegida (Motor2::LateMessage); si no se puede, queda una nota en la conversación para que alguien le escriba.
module TrackingCampaigns::EventReminders
  KINDS = %w[day_before hour_before].freeze
  # Cuándo toca cada uno: [desde, hasta] antes de que empiece.
  WINDOWS = { 'day_before' => [24.hours, 3.hours], 'hour_before' => [1.hour, 0.minutes] }.freeze
  DEFAULTS = {
    'day_before' => '¡Hola {{nombre}}! 😊 Te recordamos que mañana es {{evento}}: {{cuando}}. {{lugar}} ¡Te esperamos!',
    'hour_before' => '¡Hola {{nombre}}! En una hora empieza {{evento}}. {{liga}} ¡Nos vemos!'
  }.freeze
  MAX_TEXT = 600

  module_function

  def sanitize(raw)
    raw = raw.is_a?(Hash) ? raw.stringify_keys : {}
    {
      'day_before' => raw.key?('day_before') ? ActiveModel::Type::Boolean.new.cast(raw['day_before']) || false : true,
      'hour_before' => raw.key?('hour_before') ? ActiveModel::Type::Boolean.new.cast(raw['hour_before']) || false : true,
      'day_text' => raw['day_text'].to_s.strip.first(MAX_TEXT), 'hour_text' => raw['hour_text'].to_s.strip.first(MAX_TEXT),
      'template' => raw['template'].to_s.strip.first(200)
    }
  end

  def config(campaign) = sanitize(campaign.brief.to_h['reminders'])

  # Para la revisión antes de lanzar: [nivel, texto]. En WhatsApp, pasadas 24 h solo salen con plantilla.
  def check(campaign)
    config = config(campaign)
    on = KINDS.select { |kind| config[kind] }
    return ['warning', 'Sin recordatorios: a los que confirmen no les llega nada antes del evento.'] if on.empty?
    if campaign.inbox&.whatsapp? && config['template'].blank?
      return ['warning', 'Recordatorios sin plantilla: a quien no haya escrito en 24 h no le llegarán. Elige una en «Mensajes».']
    end

    ['ok', "Recordatorios a los que confirmen: #{on.map { |k| LABELS[k] }.join(' y ')}."]
  end

  LABELS = { 'day_before' => 'un día antes', 'hour_before' => 'una hora antes' }.freeze

  # El que toca ahora (o nil): según cuánto falta para que empiece el evento.
  def due_kind(event, now = Time.current)
    return unless event&.starts_at

    left = event.starts_at - now
    KINDS.find { |kind| left <= WINDOWS[kind][0] && left > WINDOWS[kind][1] }
  end

  def run(campaign, now = Time.current)
    event = campaign.event
    kind = due_kind(event, now)
    return 0 unless kind && config(campaign)[kind]

    sent = 0
    pending(campaign, kind).find_each do |tracking|
      deliver(campaign, event, tracking, kind)
      sent += 1
    end
    sent
  end

  # Los que lo lograron y no han recibido este recordatorio.
  def pending(campaign, kind)
    campaign.contact_trackings.where('outcome LIKE ?', 'Logrado:%')
            .where.not("COALESCE(motor2_state -> 'event_reminders', '[]'::jsonb) ? :kind", kind: kind)
  end

  def deliver(campaign, event, tracking, kind)
    text = text(campaign, event, tracking, kind)
    message = Motor2::LateMessage.deliver(tracking, text, template: config(campaign)['template'].presence)
    not_sent(tracking, kind) unless message
  rescue StandardError => e
    Rails.logger.warn("[EventReminders] tracking #{tracking.id} #{kind}: #{e.class}: #{e.message}")
  ensure
    mark(tracking, kind)
  end

  def text(campaign, event, tracking, kind)
    custom = config(campaign)[kind == 'day_before' ? 'day_text' : 'hour_text']
    fill(custom.presence || DEFAULTS[kind], values(campaign, event, tracking)).squish
  end

  def values(campaign, event, tracking)
    zone = tracking.inbox&.timezone.presence || 'America/Mexico_City'
    name = tracking.contact&.name.to_s.split.first
    { 'nombre' => (name if name.present? && !name.match?(/\A[+\d]/)).to_s, 'evento' => event.name.to_s,
      'cuando' => Motor2::Skills::Appointments.label(event.starts_at.in_time_zone(zone)),
      'lugar' => event.location.to_s, 'liga' => link(campaign, event).to_s }
  end

  # La liga para entrar: la del evento o, si no, la primera de la campaña.
  def link(campaign, event)
    event.meeting_url.presence || Array(campaign.brief.to_h['links']).filter_map { |l| l['url'].presence }.first
  end

  def fill(text, values)
    text.gsub(/\{\{\s*(\w+)\s*\}\}/) { values.fetch(Regexp.last_match(1), '') }.gsub(/\s+([.,!])/, '\1').gsub(/¡\s*!/, '¡')
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
