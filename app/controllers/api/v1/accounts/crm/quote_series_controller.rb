# CrmZeus Q1 — series de folio de cotización por agente (CTFOLIOS_USUARIOS). Solo Administrador.
#
#   GET /crm/quote_series · POST /crm/quote_series { quote_series: { user_id, series, last_number } }
#   PATCH/DELETE /crm/quote_series/:id
#
# Borrar una serie no toca las cotizaciones (guardan su folio); el agente ya no puede cotizar.
class Api::V1::Accounts::Crm::QuoteSeriesController < Api::V1::Accounts::Crm::CatalogBaseController
  private

  def relation
    Current.account.crm_quote_series.includes(:user)
  end

  def record_params
    params.require(:quote_series).permit(:user_id, :series, :last_number)
  end

  def record_json(record)
    record.slice(:id, :user_id, :series, :last_number).merge(user_name: record.user.name, next_folio: record.next_folio)
  end

  def usage_count(_record)
    0
  end
end
