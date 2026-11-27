# frozen_string_literal: true

# Campaña con IA · Ofrecer y Reactivar con objetivo «cita» — el recordatorio de la cita (Motor2::AppointmentNotice lo
# manda un día antes, o 2 h antes si es el mismo día). Igual que los recordatorios de Invitar: con la ventana abierta y
# «La IA lo escribe al momento», la IA lo escribe para ese contacto con lo que platicó (TrackingCampaigns::ReminderWriter);
# si no, el mensaje fijo (con {{nombre}} {{cuando}} {{con}}; vacío, el de fábrica). Pasadas 24 h, su plantilla (o la del
# aviso de la cita del vendedor; Motor2::LateMessage). Solo el recordatorio: el «¿otro horario?» si no llegó sigue igual.
#
#   brief['appointment_reminder'] = { 'ai' => true, 'text' => '', 'template' => '' }
#   TrackingCampaigns::AppointmentReminder.text_for(tracking, meeting) → '…' | nil (no es de una campaña así)
module TrackingCampaigns::AppointmentReminder
  KEY = 'appointment_reminder'
  KINDS = %w[offer reactivate].freeze
  DEFAULT = '¡Hola {{nombre}}! Te recuerdo tu cita del {{cuando}} con {{con}}. ¿Nos confirmas que sí llegas?'
  MAX_TEXT = 600
  BOOL = ActiveModel::Type::Boolean.new

  module_function

  def sanitize(raw)
    raw = raw.is_a?(Hash) ? raw.stringify_keys : {}
    { 'ai' => raw.key?('ai') ? BOOL.cast(raw['ai']) || false : true, 'text' => raw['text'].to_s.strip.first(MAX_TEXT),
      'template' => raw['template'].to_s.strip.first(200) }
  end

  # La plantilla para quien no ha escrito en 24 h (nil: la del vendedor).
  def template(tracking)
    campaign = tracking.tracking_campaign
    applies?(campaign) ? config(campaign)['template'].presence : nil
  end

  def config(campaign) = sanitize(campaign.brief.to_h[KEY])

  def applies?(campaign)
    brief = campaign&.brief.to_h
    campaign&.motor2? && KINDS.include?(brief['kind']) && brief['offer_goal'] == 'appointment'
  end

  def text_for(tracking, meeting)
    campaign = tracking.tracking_campaign
    return nil unless applies?(campaign)

    values = values(tracking, meeting)
    if config(campaign)['ai'] && tracking.conversation && Motor2::LateMessage.window_open?(tracking.conversation)
      written = TrackingCampaigns::ReminderWriter.new(campaign, kind: 'appointment', pending: false).for_contact(tracking, values)
    end
    written.presence || TrackingCampaigns::EventReminders.fill(config(campaign)['text'].presence || DEFAULT, values).squish
  end

  def values(tracking, meeting)
    name = tracking.contact&.name.to_s.split.first
    zone = Motor2::Config.for(tracking).zone
    { 'nombre' => (name if name.present? && !name.match?(/\A[+\d]/)).to_s,
      'cuando' => Motor2::Skills::Appointments.label(meeting.starts_at.in_time_zone(zone)),
      'con' => meeting.organizer&.name.to_s.split.first.presence || 'nosotros' }
  end
end
