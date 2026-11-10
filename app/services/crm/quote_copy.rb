# CrmZeus Q1 — «Duplicar»: una cotización nueva, sin guardar, con el encabezado y las partidas de
# otra (en CRMZeus se hace en el navegador y el agente la guarda). Fecha de hoy; la vigencia y la
# entrega conservan los días que tenían respecto a la fecha. Los impuestos se toman del catálogo
# actual (los mismos impuestos, con su % de hoy); el precio se queda como estaba.
class Crm::QuoteCopy
  HEADER = %i[organization_id contact_id shipping_address_id seller_id currency_id payment_term_id cfdi_use header_notes
              footer_notes extra_discount_type extra_discount_value freight other_charges].freeze
  ITEM = %i[role article_id key description unit price_list_id quantity unit_price discount_percent notes extra_notes position].freeze

  def initialize(source, user)
    @source = source
    @user = user
  end

  def build
    today = Time.zone.today
    dates = { quote_date: today, valid_until: shift(@source.valid_until, today), delivery_date: shift(@source.delivery_date, today) }
    quote = @source.account.crm_quotes.new(@source.slice(*HEADER).merge(dates, created_by: @user))
    copy_items(quote)
    quote.exchange_rate = quote.default_exchange_rate
    quote.preview
  end

  private

  def shift(date, today)
    date && (today + (date - @source.quote_date).to_i)
  end

  def copy_items(quote)
    copies = {}
    tops, components = @source.items.partition { |item| item.parent_item_id.nil? }
    (tops + components).each do |item|
      copies[item.id] = quote.items.build(item.slice(*ITEM).merge(parent_item: copies[item.parent_item_id],
                                                                  tax_ids: item.item_taxes.filter_map(&:tax_id)))
    end
  end
end
