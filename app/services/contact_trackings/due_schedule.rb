# frozen_string_literal: true

# Campaña con IA · Recordar — los toques en FECHAS (7 días antes, 1 día antes, el día…) según el vencimiento de cada
# contrato, en vez de «cada N días». TrackingCampaigns::RenewEnroll guarda las fechas que siguen en
# motor2_state['schedule'] (la primera ya es scheduled_for); después de cada toque, el siguiente sale de ahí.
# Si la fecha ya pasó, sale en unos minutos. Sin fechas, el intervalo de siempre.
module ContactTrackings::DueSchedule
  SOON = 5.minutes

  def next_scheduled_time
    times = Array(motor2_state.to_h['schedule'])
    return super if times.empty?

    at = times[attempt_count.to_i - 1]
    return super unless at

    [Time.zone.parse(at.to_s), SOON.from_now].max
  rescue ArgumentError, TypeError
    super
  end
end
