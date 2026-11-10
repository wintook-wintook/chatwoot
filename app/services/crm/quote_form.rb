# CrmZeus Q1 — aplica a una cotización lo que manda el formulario: el encabezado y la lista
# completa de partidas (cada kit con sus `components`). La lista reemplaza a la guardada: las
# partidas con `id` se editan, las que no traen `id` se agregan y las que faltan se borran. El
# orden de la lista es el `position`. Los importes no se aceptan: los calcula Crm::QuoteTotals.
#
#   Crm::QuoteForm.new(quote, params).apply            # alta y edición
#   Crm::QuoteForm.new(quote, params, ids: false).apply  # `calculate`: todo como partida nueva
class Crm::QuoteForm
  HEADER_FIELDS = %i[organization_id contact_id shipping_address_id seller_id currency_id payment_term_id quote_date
                     valid_until delivery_date cfdi_use purchase_order purchase_order_date header_notes footer_notes
                     extra_discount_type extra_discount_value freight other_charges].freeze
  ITEM_FIELDS = %i[id article_id description unit price_list_id quantity unit_price discount_percent notes extra_notes].freeze
  TOP_ROLES = %w[normal kit].freeze

  def self.permit(params)
    item = [*ITEM_FIELDS, :role, { tax_ids: [] }]
    params.require(:quote).permit(*HEADER_FIELDS, items: [*item, { components: item }])
  end

  def initialize(quote, attributes, ids: true)
    @quote = quote
    @attributes = attributes.to_h.with_indifferent_access
    @ids = ids
  end

  def apply
    @quote.assign_attributes(@attributes.slice(*HEADER_FIELDS))
    @quote.fill_from_organization if @quote.new_record?
    @quote.exchange_rate = @quote.default_exchange_rate
    sync_items if @attributes.key?(:items)
    @quote
  end

  private

  def sync_items
    @kept = []
    Array(@attributes[:items]).each_with_index do |row, position|
      item = assign(row, position, role: TOP_ROLES.include?(row[:role].to_s) ? row[:role].to_s : 'normal')
      sync_components(item, Array(row[:components]))
    end
    (@quote.items.to_a - @kept).each(&:mark_for_destruction)
  end

  # Un renglón que deja de ser kit pierde sus componentes (se borran por no venir en la lista).
  def sync_components(kit, rows)
    return unless kit.role_kit?

    rows.each_with_index { |row, position| assign(row, position, role: 'component', parent_item: kit) }
  end

  def assign(row, position, role:, parent_item: nil)
    item = find_or_build(row[:id])
    item.assign_attributes(row.slice(*ITEM_FIELDS - [:id]).merge(position: position, role: role, parent_item: parent_item))
    item.tax_ids = row.key?(:tax_ids) ? row[:tax_ids] : article_tax_ids(item) if row.key?(:tax_ids) || item.new_record?
    @kept << item
    item
  end

  # Partida nueva sin `tax_ids`: los impuestos del artículo.
  def article_tax_ids(item)
    CrmArticle.find_by(account_id: @quote.account_id, id: item.article_id)&.tax_ids || []
  end

  # Un id que no es de esta cotización es un 404 (no se crea una partida nueva en silencio).
  def find_or_build(id)
    return @quote.items.build if id.blank? || !@ids

    @quote.items.find { |item| item.id == id.to_i } || raise(ActiveRecord::RecordNotFound, "Partida #{id} no encontrada")
  end
end
