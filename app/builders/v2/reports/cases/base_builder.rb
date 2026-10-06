# proyecto@metricas_casos
#
# Base común de los reportes de Casos (Informes → Oportunidades). A diferencia de
# V2::Reports::Conversations::*, acá NO hay reporting_events: se consulta directo
# `case_tickets`, filtrando por los mismos ejes que el resto de Informes (rango de
# fechas) más los propios del dominio (tipo de caso, vendedor/assignee, equipo).
class V2::Reports::Cases::BaseBuilder
  include DateRangeHelper
  pattr_initialize [:account!, :params!]

  private

  # Filtros del dominio (tipo de caso, vendedor, equipo) SIN acotar todavía por
  # fecha — quien use esto decide sobre qué columna de fecha aplica el rango (la
  # mayoría filtra por `created_at`, pero un reporte de "cerrados en el período"
  # necesita acotar por `closed_at` en su lugar).
  def filtered_tickets
    tickets = account.case_tickets
    tickets = tickets.where(case_type_id: params[:case_type_id]) if params[:case_type_id].present?
    tickets = tickets.where(assignee_id: params[:assignee_id]) if params[:assignee_id].present?
    tickets = tickets.where(team_id: params[:team_id]) if params[:team_id].present?
    tickets
  end

  # `filtered_tickets` acotado por `created_at` — el filtro de fecha por defecto
  # que usan los reportes de "foto actual" (embudo, ganados/perdidos): cohortes
  # por cuándo se CREÓ la oportunidad, no por cuándo se decidió.
  def scoped_tickets
    range ? filtered_tickets.where(created_at: range) : filtered_tickets
  end

  # Ganado / perdido / otro cierre / abierto para un ticket dado su `status` y
  # `closure_type` ya normalizados (ver `enum_key`). Regla compartida por
  # DistributionBuilder#outcome y AssigneeSummaryBuilder — un solo lugar que
  # decide qué es "perdido": `status` y `closure_type` son ejes DISTINTOS acá
  # (closure_type solo se llena al cerrar por `status: closed`; un ticket puede
  # perderse sin pasar por ahí, `status: cancelled` directo).
  def outcome_bucket(status, closure)
    return :lost if status == 'cancelled'
    return :open unless status == 'closed'

    case closure
    when 'resolved'  then :won
    when 'cancelled' then :lost
    else :other_closed
    end
  end

  # Rails puede devolver las claves del group como string del enum ("open") o como
  # entero (0) según versión/driver.
  def enum_key(enum_hash, raw_value)
    return raw_value.to_s if enum_hash.key?(raw_value.to_s)

    enum_hash.key(raw_value)
  end
end
