# proyecto@metricas_casos
#
# Serie temporal de Casos: nuevas oportunidades (por created_at) vs. cerradas (por
# closed_at) agrupadas por período. A diferencia de `scoped_tickets` (que acota TODO
# por created_at), acá cada serie necesita su PROPIA columna de fecha — una
# oportunidad puede crearse en un período y cerrarse en otro, y ambas series deben
# reflejar eso en su propio eje temporal, no compartir el rango de la otra.
class V2::Reports::Cases::TimeseriesBuilder < V2::Reports::Cases::BaseBuilder
  include TimezoneHelper

  PERMITTED_GROUPS = %w[day week month year hour].freeze
  DEFAULT_GROUP_BY = 'day'.freeze

  def timeseries
    {
      created: series_for(filtered_tickets, :created_at),
      closed: series_for(filtered_tickets.where.not(closed_at: nil), :closed_at)
    }
  end

  private

  def series_for(base_scope, date_column)
    base_scope.group_by_period(
      group_by,
      date_column,
      default_value: 0,
      range: range,
      permit: PERMITTED_GROUPS,
      time_zone: timezone
    ).count.map { |date, count| { value: count, timestamp: date.in_time_zone(timezone).to_i } }
  end

  def group_by
    PERMITTED_GROUPS.include?(params[:group_by]) ? params[:group_by] : DEFAULT_GROUP_BY
  end

  def timezone
    @timezone ||= timezone_name_from_offset(params[:timezone_offset])
  end
end
