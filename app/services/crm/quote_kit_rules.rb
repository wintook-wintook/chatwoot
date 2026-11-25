# CrmZeus Q3 — reglas del kit en una cotización, contra el kit del catálogo (las mismas que pone
# la pantalla, para quien use la API directo):
#   - el kit lleva al menos un componente y ninguno puede ser un kit NO almacenable (uno almacenable
#     sí: master2 `quotations/article.js` solo rechaza el rol J, «No es posible que un juego sea componente»);
#   - un componente del catálogo solo puede faltar si es reemplazable (REEMPLAZA: se quitó o se
#     reemplazó por otro); permitir cambiar unidades (MODIFICA) no basta (decisión del usuario);
#   - un componente que NO permite cambiar unidades lleva unidades por kit × cantidad del kit.
# Los componentes agregados en la cotización (que no están en el catálogo) no tienen restricción.
# Solo revisa los kits que cambiaron (ellos o sus componentes), para que un cambio posterior en el
# catálogo no impida editar el resto de una cotización vieja.
class Crm::QuoteKitRules
  TOLERANCE = BigDecimal('0.00001')

  def initialize(quote)
    @quote = quote
    @live = quote.items.reject(&:marked_for_destruction?)
  end

  # Lista de mensajes; vacía si todo está bien.
  def errors
    @live.select(&:role_kit?).flat_map { |kit| changed?(kit) ? kit_errors(kit) : [] }
  end

  private

  def components_of(kit, items = @live)
    items.select { |item| item.role_component? && item.parent_item == kit }
  end

  def changed?(kit)
    kit.new_record? || kit.changed? || components_of(kit, @quote.items).any? do |item|
      item.new_record? || item.changed? || item.marked_for_destruction?
    end
  end

  def kit_errors(kit)
    components = components_of(kit)
    return ["el kit «#{kit.description}» debe tener al menos un componente"] if components.empty?

    nested_kit_errors(kit, components) + catalog_errors(kit, components)
  end

  def nested_kit_errors(kit, components)
    components.select { |item| item.article&.is_kit? && !item.article.is_stockable? }
              .map { |item| "«#{item.description}» es un kit no almacenable y no puede ser componente de «#{kit.description}»" }
  end

  def catalog_errors(kit, components)
    article = kit.article
    return [] unless article&.is_kit?

    by_article = components.index_by(&:article_id)
    article.components.includes(:component).flat_map do |rule|
      component_errors(kit, rule, by_article[rule.component_id])
    end
  end

  def component_errors(kit, rule, item)
    name = "«#{rule.component.name}» del kit «#{kit.description}»"
    return ["#{name} no es reemplazable: no se puede quitar ni cambiar por otro"] if item.nil? && !rule.replaceable
    return [] if item.nil?
    return [] if rule.units_editable

    expected = rule.quantity * kit.quantity
    (item.quantity - expected).abs > TOLERANCE ? ["#{name} no permite cambiar unidades (lleva #{expected.to_f})"] : []
  end
end
