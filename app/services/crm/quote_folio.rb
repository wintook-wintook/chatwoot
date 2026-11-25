# CrmZeus Q0 — folio de una cotización nueva: serie del agente que la crea + siguiente consecutivo
# (getFolio / F_Folio de CRMZeus). El renglón de la serie se bloquea dentro de la transacción del
# guardado, así que dos agentes no sacan el mismo folio; si el folio ya existe (p. ej. se bajó el
# consecutivo a mano) se brinca al siguiente libre (decisión del usuario; master2 responde «El Folio:
# X ya existe.» y no guarda). `last_number` es el último usado; el CONSECUTIVO de master2 es el
# siguiente a usar, así que al migrar series va `CONSECUTIVO - 1`.
class Crm::QuoteFolio
  def initialize(quote)
    @quote = quote
  end

  def assign
    series = CrmQuoteSeries.lock.find_by!(account_id: @quote.account_id, user_id: @quote.created_by_id)
    number = series.last_number + 1
    number += 1 while taken?(series.series, number)
    @quote.assign_attributes(series: series.series, number: number, folio: CrmQuoteSeries.folio(series.series, number))
    series.update!(last_number: number)
  end

  private

  def taken?(series, number)
    CrmQuote.exists?(account_id: @quote.account_id, folio: CrmQuoteSeries.folio(series, number))
  end
end
