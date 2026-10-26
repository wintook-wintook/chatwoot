# frozen_string_literal: true

# @tickets_cases — Plan-Metricas-Comercial M2: oportunidades ESTANCADAS (a pedido,
# botón «Calcular estancadas» en «Dinero en juego»).
#
# Días en la etapa actual = desde el último cambio de etapa: de columna
# (`column_changed`, mismo estado) o de estado (las transiciones; mover de columna
# cruzando de estado deja la transición, no `column_changed`). Sin ninguno, desde
# el alta. A diferencia de StageDurationBuilder (#stalled), mide la ETAPA del
# embudo y no el estado: en Comercial varias etapas comparten `in_progress`.
# Mismos filtros que el embudo (tipo, vendedor, equipo, moneda, cierre).
class V2::Reports::Cases::PipelineStaleBuilder < V2::Reports::Cases::PipelineBuilder
  DEFAULT_THRESHOLD_DAYS = 15
  STAGE_EVENTS = (V2::Reports::Cases::StageDurationBuilder::TRANSITION_EVENT_TYPES + %w[column_changed]).freeze

  def build
    rows = stale_rows
    { threshold_days: threshold_days, by_stage: rows.group_by { |r| r[:stage] }.transform_values(&:size),
      items: rows }
  end

  private

  def threshold_days
    days = params[:threshold_days].to_i
    days.positive? ? days : DEFAULT_THRESHOLD_DAYS
  end

  def stale_rows
    tickets = open_scope.includes(:assignee, :case_type_column).to_a
    last_change = CaseEvent.where(case_ticket_id: tickets.map(&:id), event_type: STAGE_EVENTS)
                           .group(:case_ticket_id).maximum(:created_at)
    rows = tickets.filter_map do |ticket|
      days = ((Time.current - (last_change[ticket.id] || ticket.created_at)) / SECONDS_PER_DAY).floor
      opportunity_row(ticket).merge(days_in_stage: days) if days >= threshold_days
    end
    rows.sort_by { |r| -r[:days_in_stage] }
  end
end
