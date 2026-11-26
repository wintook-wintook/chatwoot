# frozen_string_literal: true

# Campaña con IA · Ofrecer y Reactivar — el «Último aviso»: un día antes de que termine la promoción (brief valid_until),
# a quien recibió la oferta y nunca contestó. Es lo mismo que la última invitación de Invitar
# (TrackingCampaigns::EventReminders), con la vigencia en lugar de la fecha del evento. Lo corre
# TrackingCampaigns::EventReminderJob cada 10 min.
#
#   brief['last_call'] = { 'on' => true, 'ai' => true, 'text' => '', 'template' => '' }
#     on        prendido (de fábrica, sí, si hay vigencia)
#     ai        con la ventana abierta lo escribe la IA al momento para cada contacto (TrackingCampaigns::ReminderWriter);
#               en false, el texto (con {{nombre}} {{oferta}} {{cuando}} {{liga}}; vacío, el de fábrica)
#     template  plantilla de WhatsApp para quien no ha escrito en 24 h
# Cada uno una sola vez (motor2_state['event_reminders'] lleva 'last_call'); sin baja y sin un toque reciente.
module TrackingCampaigns::LastCall
  KEY = 'last_call'
  KINDS = %w[offer reactivate].freeze
  DEFAULT = '¡Hola {{nombre}}! La promoción de {{oferta}} termina {{cuando}}. ¿Te la aparto? {{liga}}'
  # Cuándo sale: desde 30 h hasta 4 h antes de que termine (el día antes por la tarde o el mismo día temprano).
  WINDOW = [30.hours, 4.hours].freeze
  MAX_TEXT = 600
  BOOL = ActiveModel::Type::Boolean.new
  Reminders = TrackingCampaigns::EventReminders

  module_function

  def sanitize(raw)
    raw = raw.is_a?(Hash) ? raw.stringify_keys : {}
    { 'on' => flag(raw, 'on'), 'ai' => flag(raw, 'ai'), 'text' => raw['text'].to_s.strip.first(MAX_TEXT),
      'template' => raw['template'].to_s.strip.first(200) }
  end

  def flag(raw, key) = raw.key?(key) ? BOOL.cast(raw[key]) || false : true

  def config(campaign) = sanitize(campaign.brief.to_h[KEY])

  def ends_at(campaign) = TrackingCampaigns::OfferProducts.ends_at(campaign.brief.to_h['valid_until'])

  def applies?(campaign) = KINDS.include?(campaign.brief.to_h['kind']) && ends_at(campaign).present?

  def due?(campaign, now = Time.current)
    limit = ends_at(campaign)
    left = limit && (limit - now)
    left.present? && left <= WINDOW[0] && left > WINDOW[1]
  end

  def run(campaign, now = Time.current)
    return 0 unless applies?(campaign) && config(campaign)['on'] && due?(campaign, now)

    Reminders.not_answered(campaign, KEY).to_a.count { |tracking| Reminders.ready?(tracking) && deliver(campaign, tracking, now) }
  end

  def deliver(campaign, tracking, now)
    Motor2::LateMessage.deliver(tracking, text_for(campaign, tracking, now), template: config(campaign)['template'].presence)
    true
  rescue StandardError => e
    Rails.logger.warn("[LastCall] tracking #{tracking.id}: #{e.class}: #{e.message}")
    false
  ensure
    Reminders.mark(tracking, KEY)
  end

  # Con la ventana abierta y «La IA lo escribe al momento»: para ese contacto (si falla, el texto).
  def text_for(campaign, tracking, now = Time.current)
    values = values(campaign, tracking, now)
    if config(campaign)['ai'] && tracking.conversation && Motor2::LateMessage.window_open?(tracking.conversation)
      written = TrackingCampaigns::ReminderWriter.new(campaign, kind: KEY, pending: true).for_contact(tracking, values)
    end
    written.presence || Reminders.fill(config(campaign)['text'].presence || DEFAULT, values).squish
  end

  def values(campaign, tracking, now = Time.current)
    name = tracking.contact&.name.to_s.split.first
    { 'nombre' => (name if name.present? && !name.match?(/\A[+\d]/)).to_s, 'oferta' => campaign.brief.to_h['offer_what'].to_s,
      'cuando' => when_text(campaign, now), 'liga' => link(campaign) }
  end

  # «hoy» si ya es el último día; si no, «mañana».
  def when_text(campaign, now)
    limit = ends_at(campaign)
    limit.to_date == now.in_time_zone(limit.time_zone).to_date ? 'hoy' : 'mañana'
  end

  def link(campaign) = Array(campaign.brief.to_h['links']).find { |l| l['use'] == 'package' }&.dig('url').to_s

  # Para la revisión antes de lanzar: [nivel, texto] o nil si no aplica.
  def check(campaign)
    return nil unless applies?(campaign)

    config = config(campaign)
    return ['warning', 'Sin «Último aviso»: a quien no contestó no le llega nada antes de que termine la promoción.'] unless config['on']
    if campaign.inbox&.whatsapp? && config['template'].blank?
      return ['warning', '«Último aviso» sin plantilla: a quien no haya escrito en 24 h no le llegará. Elige una en «Mensajes».']
    end

    ['ok', 'Último aviso: un día antes de que termine la promoción, a quien no ha contestado.']
  end
end
