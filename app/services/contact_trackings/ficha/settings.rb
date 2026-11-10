# frozen_string_literal: true

# ================================================================================
# feat/ficha_agente_ia — LOS AJUSTES DE LA FICHA QUE NO SON RECURSOS
# ================================================================================
# Lee (y limpia) lo que manda la pantalla además de las tarjetas: Canal y seguimiento,
# Agenda, Reglas y la regla de envío de cada archivo. Cada método regresa SOLO lo que
# vino (nil o {} si no vino), para no pisar lo que el agente ya tiene.
# ================================================================================

class ContactTrackings::Ficha::Settings
  KEYWORD_FIELDS = [:keyword, :action, :direction, :label, :assignee_id, :team_id].freeze
  PRESENTATIONS = %w[detailed by_agent by_calendar simple].freeze
  UNITS = %w[minutes hours days].freeze

  def initialize(params)
    @params = params
  end

  # Canal y seguimiento: cada cuánto, con qué plantilla de WhatsApp cada intento, la firma.
  def follow_up
    unidad = @params[:retry_interval_unit].to_s
    { retry_interval_value: positive(@params[:retry_interval_value]),
      retry_interval_unit: UNITS.include?(unidad) ? unidad : nil,
      whatsapp_templates: @params.key?(:whatsapp_templates) ? Array(@params[:whatsapp_templates]).map(&:to_s) : nil,
      email_signature: @params[:email_signature].presence }.compact
  end

  # Cuántos intentos (sin plantillas; ver TrackingTemplate#follow_up_attempts).
  def attempts
    intentos = positive(@params[:attempts])
    intentos ? { 'attempts' => intentos.clamp(1, 10) } : {}
  end

  # { 'catalogo' => { 'ask' =>, 'welcome' =>, 'attempts' => [] } } de un agente que ya existe.
  def file_rules
    crudo = @params[:file_rules]
    return nil if crudo.nil?

    crudo = crudo.to_unsafe_h if crudo.respond_to?(:to_unsafe_h)
    crudo.to_h.transform_values { |regla| self.class.rule(regla) }
  end

  def self.rule(regla)
    r = regla.to_h.stringify_keys
    cast = ActiveModel::Type::Boolean.new
    { 'ask' => cast.cast(r.fetch('ask', true)), 'welcome' => cast.cast(r['welcome']) || false,
      'attempts' => Array(r['attempts']).map(&:to_i).select(&:positive?).uniq.sort }
  end

  # Agenda: duración, zona, presentación y calendarios (solo de las agendas marcadas).
  def agenda(integraciones)
    agenda = @params[:agenda]
    return {} if agenda.blank?

    agenda = agenda.permit(:calendar_event_duration, :timezone, :slots_presentation, booking_calendar_ids: {}).to_h
    { calendar_event_duration: positive(agenda['calendar_event_duration']), timezone: agenda['timezone'],
      slots_presentation: PRESENTATIONS.include?(agenda['slots_presentation']) ? agenda['slots_presentation'] : nil,
      booking_calendar_ids: booking_ids(agenda['booking_calendar_ids'], integraciones) }.compact
  end

  # Reglas (palabras clave → acción). nil = no vinieron.
  def keyword_actions
    return nil unless @params.key?(:keyword_actions)

    @params.permit(keyword_actions: KEYWORD_FIELDS).fetch(:keyword_actions, []).map { |r| r.to_h.stringify_keys }
  end

  private

  def positive(valor) = valor.to_i.positive? ? valor.to_i : nil

  def booking_ids(raw, integraciones)
    return nil if raw.nil?

    permitidas = integraciones.map(&:to_s)
    raw.to_h.each_with_object({}) do |(id, cals), acc|
      lista = Array(cals).map(&:to_s).compact_blank.uniq
      acc[id.to_s] = lista if lista.any? && permitidas.include?(id.to_s)
    end
  end
end
