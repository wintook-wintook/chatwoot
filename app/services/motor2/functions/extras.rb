# frozen_string_literal: true

# Lo que tienen igual los tres agentes listos (Atención a prospectos, Atención a clientes, Vendedor de campaña),
# para que ninguno se quede atrás. En answers:
#   follow_up            { nudges 0-2, templates [], template_days }  si deja de contestar (Motor2::FollowUp)
#   appointment_notice   { on, template }  recordatorio de la cita y «¿otro horario?» si no llegó (Motor2::AppointmentNotice)
#   attend_hours         en cuántas horas hábiles le debe escribir alguien al pasarlo (Motor2::AttendClock)
#   quote                { mode off | draft | send, follow_days }  cotizar (Motor2::Skills::Quote)
# Los agentes de antes (sin guardar) quedan sin nada de esto hasta que lo prendan.
module Motor2::Functions::Extras
  QUOTE_MODES = %w[off draft send].freeze

  # Lo que manda el asistente, limpio.
  def self.sanitize(raw)
    raw = Motor2::Sanitizer.plain(raw)
    { 'follow_up' => follow_up(raw['follow_up']), 'appointment_notice' => notice(raw['appointment_notice']),
      'attend_hours' => raw['attend_hours'].to_s.presence&.to_i&.clamp(0, 48), 'quote' => quote(raw['quote']) }.compact
  end

  def self.follow_up(raw)
    raw = Motor2::Sanitizer.plain(raw)
    return nil if raw.empty?

    { 'nudges' => raw['nudges'].to_i.clamp(0, Motor2::FollowUp::NUDGE_HOURS.size),
      'templates' => Array(raw['templates']).map { |t| t.to_s.strip.first(200) }.compact_blank.first(5),
      'template_days' => raw['template_days'].to_i.clamp(1, 7) }
  end

  def self.notice(raw)
    raw = Motor2::Sanitizer.plain(raw)
    return nil if raw.empty?

    { 'on' => ActiveModel::Type::Boolean.new.cast(raw['on']) || false, 'template' => raw['template'].to_s.strip.first(200).presence }.compact
  end

  def self.quote(raw)
    raw = Motor2::Sanitizer.plain(raw)
    return nil if raw.empty?

    { 'mode' => raw['mode'].to_s.presence_in(QUOTE_MODES) || 'off', 'follow_days' => raw['follow_days'].to_i.clamp(1, 15) }
  end

  def follow_up
    saved = answer(:follow_up).to_h
    { nudges: saved['nudges'].to_i.clamp(0, Motor2::FollowUp::NUDGE_HOURS.size), templates: Array(saved['templates']),
      template_days: saved['template_days'].to_i.clamp(1, 7) }
  end

  def appointment_notice
    saved = answer(:appointment_notice).to_h
    { on: saved['on'] == true, template: saved['template'].to_s.presence }
  end

  def attend_hours = answer(:attend_hours).to_i.clamp(0, 48)

  def quote_mode = answer(:quote).to_h['mode'].to_s.presence_in(QUOTE_MODES) || 'off'

  def quote_follow_days = answer(:quote).to_h['follow_days'].to_i.clamp(1, 15)
end
