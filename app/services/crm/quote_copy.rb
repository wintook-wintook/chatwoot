# CrmZeus Q1 — «Duplicar»: una cotización nueva, sin guardar (en CRMZeus se hace en el navegador y el
# agente la guarda). Fecha, vigencia y entrega: hoy (master2 `quotations/form.js` duplicate).
#
# Q3.1: como master2, se copia lo que hay en pantalla (`attributes`, el mismo cuerpo del alta), no lo
# guardado; sin `attributes` (p. ej. al recargar `?from=`) se copia la guardada. Se arma con
# Crm::QuoteForm (como `calculate`, con la guardada en `stored` para respetar sus impuestos). No se
# copian las partidas cuyo artículo esté de baja o suspendido de ventas (master2 `articles/getStatus`:
# ESTATUS NOT IN ('A', 'C')); un kit se va con sus componentes. Solo se revisan las partidas de primer
# nivel, como master2. Los nombres quitados quedan en `removed` para el aviso. La OC se copia (master2 no la limpia).
class Crm::QuoteCopy
  HEADER = %i[organization_id contact_id shipping_address_id seller_id currency_id payment_term_id cfdi_use purchase_order
              purchase_order_date header_notes footer_notes extra_discount_type extra_discount_value freight
              other_charges].freeze
  ITEM = %i[role article_id description unit price_list_id quantity unit_price discount_percent notes extra_notes].freeze
  BLOCKED_STATUSES = %w[inactive sales_suspended suspended].freeze

  attr_reader :removed

  def initialize(source, user, attributes = nil)
    @source = source
    @user = user
    @attributes = (attributes || saved_attributes).to_h.with_indifferent_access
    @removed = []
  end

  def build
    today = Time.zone.today
    attributes = @attributes.slice(*HEADER).merge(quote_date: today, valid_until: today, delivery_date: today,
                                                  items: copied_rows)
    quote = @source.account.crm_quotes.new(created_by: @user)
    Crm::QuoteForm.new(quote, attributes, ids: false, stored: @source).apply.preview
  end

  private

  def copied_rows
    rows = Array(@attributes[:items])
    articles = @source.account.crm_articles.where(id: rows.pluck(:article_id).compact).index_by(&:id)
    rows.reject do |row|
      article = articles[row[:article_id].to_i]
      next false unless article && BLOCKED_STATUSES.include?(article.status)

      @removed |= [article.name]
    end
  end

  def saved_attributes
    tops, components = @source.items.partition { |item| item.parent_item_id.nil? }
    @source.slice(*HEADER).merge(items: tops.map do |top|
      kit_components = components.select { |item| item.parent_item_id == top.id }
      top.role_kit? ? row(top).merge(components: kit_components.map { |item| row(item) }) : row(top)
    end)
  end

  def row(item)
    item.slice(:id, *ITEM).merge(tax_ids: item.item_taxes.filter_map(&:tax_id))
  end
end
