# frozen_string_literal: true

# «Atención a clientes» — las reglas propias de cada área y su horario (las pone la empresa en el asistente):
#   rules   «Comercial: nunca ofrezcas descuentos; los precios ya incluyen IVA» (solo las ve el área en curso)
#   hours   { from: '09:00', to: '14:00', days: 'weekdays' | 'all' }: fuera de ese horario el agente toma lo que necesita y
#           le dice que el equipo le escribe en cuanto abra (sin prometer hora).
# También el recordatorio del seguimiento corto (attempt_note). Lo usa Motor2::Skills::Areas (turn_note).
# Los otros dos agentes usan sus Indicaciones y el horario de la bandeja.
module Motor2::Skills::AreaRules
  DAYS = { 'weekdays' => 'lunes a viernes', 'saturday' => 'lunes a sábado', 'all' => 'todos los días' }.freeze

  private

  # El recordatorio del seguimiento corto (Motor2::FollowUp): retoma lo pendiente, en una o dos frases.
  def attempt_note
    return 'Pregúntale con amabilidad, en una frase, si se resolvió con lo que le pasaste (que conteste RESUELTO o ESCALAR).' if
      state['opciones']

    'Retoma con amabilidad lo que quedó pendiente (la pregunta o el dato que le pediste), en una frase. No busques ni levantes nada.'
  end

  def area_rules_note
    return nil if area_key == 'none'

    data = function.area(area_key).to_h
    lines = []
    lines << "REGLAS DE #{area_title.upcase} (las puso la empresa; mandan): #{data['rules']}" if data['rules'].present?
    lines << off_hours_note(data['hours']) if off_hours?(data['hours'])
    lines.join("\n").presence
  end

  def off_hours?(hours)
    hours = hours.to_h
    return false if hours['from'].blank? || hours['to'].blank?

    now = Time.current.in_time_zone(config.zone)
    open_day = case hours['days']
               when 'all' then true
               when 'saturday' then !now.sunday?
               else !now.saturday? && !now.sunday?
               end
    !(open_day && now.strftime('%H:%M').between?(hours['from'], hours['to']))
  end

  def off_hours_note(hours)
    "Ahora está FUERA DEL HORARIO de #{area_title} (de #{hours['from']} a #{hours['to']}, #{DAYS[hours['days']] || DAYS['weekdays']}): " \
      'toma lo que necesita y dile que el equipo le escribe en cuanto abra (sin prometer una hora exacta).'
  end
end
