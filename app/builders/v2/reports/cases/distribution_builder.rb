# proyecto@metricas_casos
#
# Reportes de "distribución" sobre Casos: agrupar los tickets filtrados por un eje
# (columna del Kanban, motivo de cierre, ...) y contar. Todos comparten el mismo
# shape (group + count/sum sobre `scoped_tickets`); van sumándose acá a medida que
# se construyen (embudo primero, después ganados/perdidos y motivos de pérdida).
class V2::Reports::Cases::DistributionBuilder < V2::Reports::Cases::BaseBuilder
  # Embudo: cantidad de casos por columna del Kanban del Tipo de Caso indicado. Las
  # columnas de un tipo no son comparables con las de otro (nombres/orden propios),
  # así que sin `case_type_id` cae a agrupar por `status` canónico (across-type).
  def funnel
    return funnel_by_status if params[:case_type_id].blank?

    counts = scoped_tickets.group(:case_type_column_id).count
    buckets = columns_for_type.map do |column|
      {
        id: column.id,
        label: column.label,
        color: column.color,
        position: column.position,
        count: counts[column.id] || 0
      }
    end
    add_unassigned_bucket(buckets, counts)
  end

  # Ganados / perdidos / otros cierres / abiertos, sobre los tickets filtrados.
  # `status` y `closure_type` son ejes DISTINTOS (ver CaseTicket): `closure_type`
  # solo se llena al cerrar (`status: closed`) — un ticket puede perderse sin pasar
  # por ahí (`status: cancelled` directo, ej. el cliente desapareció a mitad de
  # camino). Por eso "perdido" mira ambos, no solo closure_type.
  def outcome
    raw = scoped_tickets.group(:status, :closure_type).count
    buckets = { open: 0, won: 0, lost: 0, other_closed: 0 }
    raw.each do |(status_raw, closure_raw), count|
      status = enum_key(CaseTicket.statuses, status_raw)
      closure = closure_raw.nil? ? nil : enum_key(CaseTicket.closure_types, closure_raw)
      buckets[outcome_bucket(status, closure)] += count
    end
    buckets
  end

  private

  def columns_for_type
    CaseTypeColumn.where(account_id: account.id, case_type_id: params[:case_type_id]).ordered
  end

  # Un ticket puede quedar sin columna (nunca se le asignó una, o el resync la vació
  # porque su status dejó de estar cubierto por ninguna — ver `CaseTicket#resync_type_column`).
  # Sin este bucket esos tickets desaparecerían del embudo en silencio. `label: nil` a
  # propósito: el texto ("Sin columna") lo decide el frontend vía i18n, como el resto
  # de estos reportes (acá solo viajan ids/counts).
  def add_unassigned_bucket(buckets, counts)
    unassigned = counts[nil] || 0
    return buckets if unassigned.zero?

    buckets + [{ id: nil, label: nil, color: '#94a3b8', position: buckets.size, count: unassigned }]
  end

  # `label: nil` a propósito, igual que el bucket "sin columna": el status es un
  # valor de enum fijo, no texto configurable por cuenta como `column.label` — el
  # frontend lo traduce vía i18n (CASE_TICKETS.STATUSES.<status>).
  def funnel_by_status
    raw = scoped_tickets.group(:status).count
    normalized = raw.each_with_object(Hash.new(0)) { |(k, v), h| h[enum_key(CaseTicket.statuses, k)] += v }
    CaseTicket.statuses.keys.map { |status| { id: status, label: nil, count: normalized[status] } }
  end
end
