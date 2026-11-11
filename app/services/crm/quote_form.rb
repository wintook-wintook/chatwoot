# CrmZeus Q1 — aplica a una cotización lo que manda el formulario: el encabezado y la lista
# completa de partidas (cada kit con sus `components`). La lista reemplaza a la guardada: las
# partidas con `id` se editan, las que no traen `id` se agregan y las que faltan se borran. El
# orden de la lista es el `position`. Los importes no se aceptan: los calcula Crm::QuoteTotals.
#
# Q3: un kit sin `components` en la petición toma los del catálogo (unidades por kit × cantidad); un
# renglón sin artículo no puede ser kit.
#
# Q3.1: los impuestos de una partida con artículo los decide el servidor (ver `assign_taxes`).
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

  # `stored`: en `calculate` de una cotización ya guardada, la guardada (para que la vista previa
  # respete sus impuestos igual que el guardado).
  def initialize(quote, attributes, ids: true, stored: nil)
    @quote = quote
    @attributes = attributes.to_h.with_indifferent_access
    @ids = ids
    @stored = stored
  end

  def apply
    @quote.assign_attributes(@attributes.slice(*HEADER_FIELDS))
    @organization_changed = organization_changed?
    @quote.fill_from_organization if @quote.new_record?
    @quote.exchange_rate = @quote.default_exchange_rate
    sync_items if @attributes.key?(:items)
    @quote
  end

  private

  def sync_items
    @kept = []
    Array(@attributes[:items]).each_with_index do |row, position|
      item = assign(row, position, role: top_role(row))
      if row.key?(:components) || item.new_record?
        sync_components(item, row.key?(:components) ? Array(row[:components]) : catalog_components(item))
      elsif item.role_kit?
        keep_components(item)
      end
    end
    (@quote.items.to_a - @kept).each(&:mark_for_destruction)
  end

  def top_role(row)
    role = row[:role].to_s
    return 'normal' unless TOP_ROLES.include?(role)
    return 'normal' if role == 'kit' && row[:article_id].blank?

    role
  end

  # Kit ya guardado que se edita sin mandar `components`: se quedan los que tenía, y si cambió la
  # cantidad del kit sus unidades cambian en la misma proporción.
  def keep_components(kit)
    components = @quote.items.select { |item| item.parent_item_id == kit.id }
    old_quantity = kit.quantity_was
    if kit.quantity_changed? && old_quantity.to_d.positive?
      components.each { |item| item.quantity = (item.quantity * kit.quantity / old_quantity).round(5) }
    end
    @kept.concat(components)
  end

  # Kit nuevo sin componentes en la petición: los del artículo en el catálogo, sin impuestos (van sin importe).
  def catalog_components(kit)
    return [] unless kit.role_kit?

    article = CrmArticle.find_by(account_id: @quote.account_id, id: kit.article_id)
    return [] unless article

    article.components.includes(:component).map do |row|
      { article_id: row.component_id, quantity: row.quantity * kit.quantity, tax_ids: [] }.with_indifferent_access
    end
  end

  # Un renglón que deja de ser kit pierde sus componentes (se borran por no venir en la lista).
  def sync_components(kit, rows)
    return unless kit.role_kit?

    rows.each_with_index { |row, position| assign(row, position, role: 'component', parent_item: kit) }
  end

  def assign(row, position, role:, parent_item: nil)
    item = find_or_build(row[:id])
    item.assign_attributes(row.slice(*ITEM_FIELDS - [:id]).merge(position: position, role: role, parent_item: parent_item))
    assign_taxes(item, row)
    @kept << item
    item
  end

  # Q3.1 — impuestos de la partida como CRMZeus. Se toman del artículo, filtrados por el cliente
  # (trasladados si cobra impuestos, retenciones si retiene; getPrice, `utils.js:4800-4835`), solo
  # cuando la partida es nueva, cambia de artículo o la cotización cambia de organización (setOrg →
  # resetPrices). Si no, se quedan los guardados en crm_quote_item_taxes (IMPUESTOS_DCDOCTOS_PDV_DET),
  # como hace CRMZeus al abrir una cotización. Lo que mande el navegador para una partida con
  # artículo se ignora. Una partida libre lleva los que mande, también filtrados por el cliente.
  # Los componentes de un kit van sin importe: llevan lo que se mande (vacío desde el catálogo).
  def assign_taxes(item, row)
    return assign_sent_taxes(item, row) if item.role_component? || item.article_id.blank?

    stored = stored_item(item, row)
    if retax?(item, stored)
      item.tax_ids = applicable_ids(CrmArticle.find_by(account_id: @quote.account_id, id: item.article_id)&.taxes.to_a)
    elsif !stored.equal?(item)
      item.tax_ids = stored.tax_ids
    end
  end

  def retax?(item, stored)
    stored.nil? || @organization_changed || article_changed?(item, stored)
  end

  def assign_sent_taxes(item, row)
    return unless row.key?(:tax_ids) || item.new_record?

    ids = Array(row[:tax_ids]).compact_blank
    item.tax_ids = item.role_component? ? ids : applicable_ids(CrmTax.where(id: ids).to_a)
  end

  # La partida tal como está guardada: la misma (alta/edición) o la de la cotización guardada (`calculate`).
  def stored_item(item, row)
    return (item.persisted? ? item : nil) if @ids
    return if @stored.nil? || row[:id].blank?

    @stored.items.find { |stored| stored.id == row[:id].to_i }
  end

  def article_changed?(item, stored)
    stored.equal?(item) ? item.article_id_changed? : stored.article_id != item.article_id
  end

  def organization_changed?
    return @quote.organization_id_changed? if @quote.persisted?

    @stored.present? && @stored.organization_id != @quote.organization_id
  end

  # Sin organización no se filtra: la validación de la cotización avisa que falta.
  def applicable_ids(taxes)
    taxes = @quote.organization.applicable_taxes(taxes) if @quote.organization
    taxes.map(&:id)
  end

  # Un id que no es de esta cotización es un 404 (no se crea una partida nueva en silencio).
  def find_or_build(id)
    return @quote.items.build if id.blank? || !@ids

    @quote.items.find { |item| item.id == id.to_i } || raise(ActiveRecord::RecordNotFound, "Partida #{id} no encontrada")
  end
end
