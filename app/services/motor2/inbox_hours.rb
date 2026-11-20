# frozen_string_literal: true

# Motor 2.0 — el horario de atención de la bandeja (si lo tiene prendido), para los tres agentes listos: para
# «¿abren el domingo?» y para saber si AHORA está fuera de horario (entonces usa lo de «Fuera de horario, qué decir»
# de «Cómo habla tu empresa» y, si toca pasarlo, le dice que le escriben en cuanto abran). Va en lo del momento
# (Motor2::Prompt#moment). Antes solo lo tenía «Atención a prospectos».
module Motor2::InboxHours
  WEEKDAYS = %w[domingo lunes martes miércoles jueves viernes sábado].freeze

  module_function

  def block(inbox, zone)
    return '' unless inbox.respond_to?(:working_hours_enabled?) && inbox.working_hours_enabled?

    days = inbox.working_hours.sort_by { |w| (w.day_of_week + 6) % 7 }.map { |w| "#{WEEKDAYS[w.day_of_week]} #{hours_text(w)}" }
    ["HORARIO DE ATENCIÓN (#{zone.tzinfo.name}): #{days.join('; ')}.", off_hours(inbox)].compact.join("\n")
  end

  def off_hours(inbox)
    return unless inbox.respond_to?(:out_of_office?) && inbox.out_of_office?

    'AHORA ESTÁ FUERA DEL HORARIO DE ATENCIÓN: atiéndelo igual; usa lo de «Fuera de horario, qué decir» (ASÍ HABLA LA ' \
      'EMPRESA) si lo hay y, si toca pasarlo a una persona, dile que le escriben en cuanto abran.'
  end

  def hours_text(hours)
    return 'cerrado' if hours.closed_all_day?
    return 'todo el día' if hours.open_all_day?

    format('%<oh>02d:%<om>02d a %<ch>02d:%<cm>02d', oh: hours.open_hour.to_i, om: hours.open_minutes.to_i,
                                                    ch: hours.close_hour.to_i, cm: hours.close_minutes.to_i)
  end
end
