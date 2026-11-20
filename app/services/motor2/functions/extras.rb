# frozen_string_literal: true

# Lo que tienen igual los tres agentes listos (Atención a prospectos, Atención a clientes, Vendedor de campaña),
# para que ninguno se quede atrás. En answers:
#   follow_up            { nudges 0-2, templates [], template_days }  si deja de contestar (Motor2::FollowUp)
#   appointment_notice   { on, template }  recordatorio de la cita y «¿otro horario?» si no llegó (Motor2::AppointmentNotice)
#   attend_hours         en cuántas horas hábiles le debe escribir alguien al pasarlo (Motor2::AttendClock)
#   quote                { mode off | draft | send, follow (true), follow_days, template }  cotizar (Motor2::Skills::Quote);
#                        template: su plantilla propia para preguntar por ella pasadas 24 h (no la de follow_up)
#   business_mode        company (los datos del negocio de «Cómo habla tu empresa») | own (los de este agente,
#                        business_what…business_practical); sin guardar: own si tiene alguno lleno (los de antes)
# Los agentes de antes (sin guardar) quedan sin nada de esto hasta que lo prendan.
module Motor2::Functions::Extras
  QUOTE_MODES = %w[off draft send].freeze
  BUSINESS_KEYS = %w[business_what business_who business_coverage business_why business_practical].freeze

  # Lo que manda el asistente, limpio.
  def self.sanitize(raw)
    raw = Motor2::Sanitizer.plain(raw)
    { 'follow_up' => follow_up(raw['follow_up']), 'appointment_notice' => notice(raw['appointment_notice']),
      'attend_hours' => raw['attend_hours'].to_s.presence&.to_i&.clamp(0, 48), 'quote' => quote(raw['quote']),
      'business_mode' => raw['business_mode'].to_s.presence_in(%w[company own]) }.compact
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

    { 'mode' => raw['mode'].to_s.presence_in(QUOTE_MODES) || 'off', 'follow' => raw['follow'].to_s != 'false',
      'follow_days' => raw['follow_days'].to_i.clamp(1, 15), 'template' => raw['template'].to_s.strip.first(200).presence }.compact
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

  # Datos del negocio personalizados para este agente (si no, los de la empresa).
  def own_business?
    mode = answer(:business_mode).to_s
    mode == 'own' || (mode.blank? && BUSINESS_KEYS.any? { |k| answer(k).present? })
  end

  # El dato del negocio que vale para este agente: el suyo o el de la empresa.
  def business_info(key) = own_business? ? answer(key).to_s : company_business[key.to_s.delete_prefix('business_')].to_s

  # Para su bloque de EL NEGOCIO: solo si los personalizó (los de la empresa van en DATOS DEL NEGOCIO, Motor2::Prompt).
  def own_business(key) = own_business? ? answer(key) : nil

  # Personalizados: los de la empresa no se repiten en DATOS DEL NEGOCIO (AgentBase::BusinessData.block skip).
  def business_values = own_business? ? BUSINESS_KEYS.map { |k| answer(k).to_s } + company_business.values : []

  def company_business = @company_business ||= AgentBase::BusinessData.get(config.account)['fixed']

  def quote_mode = answer(:quote).to_h['mode'].to_s.presence_in(QUOTE_MODES) || 'off'

  def quote_follow_days = answer(:quote).to_h['follow_days'].to_i.clamp(1, 15)

  # ¿Le pregunta por la cotización a los N días? (en los dos modos; en borrador, desde que el vendedor la manda)
  def quote_follow? = quote_mode != 'off' && answer(:quote).to_h['follow'] != false

  # Su plantilla propia (pasadas 24 h); nil si no eligió.
  def quote_template = answer(:quote).to_h['template'].presence
end
