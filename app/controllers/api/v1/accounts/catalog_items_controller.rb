# Plan-Catalogo-Cotizaciones C1 — Ventas › Catálogo.
#
#   GET   /catalog_items            ?q= &kind= &category_id= (con sus subcategorías) &active=true|false|all &page=
#   GET   /catalog_items/categories las categorías activas (texto completo, para sugerir)
#   GET   /catalog_items/export     CSV
#   POST  /catalog_items/import     CSV (file): actualiza por clave, si no, por nombre
#   POST  /catalog_items            PATCH /catalog_items/:id
#   POST  /catalog_items/:id/image  (image) · DELETE /catalog_items/:id/image   la foto del producto
#
# Lo consulta quien tiene Ventas o Servicio; lo edita Ventas con «Todo» (o el
# Administrador). El costo solo viaja con «Ver montos». No se borra: se desactiva.
class Api::V1::Accounts::CatalogItemsController < Api::V1::Accounts::BaseController
  require 'csv'

  PER_PAGE = 50
  CSV_COLUMNS = %w[clave nombre tipo categoria unidad precio moneda costo descripcion activo impuesto precio_con_impuesto clave_sat
                   retenciones].freeze

  before_action :check_read_access
  before_action :check_write_access, only: %i[create update import image remove_image]
  before_action :set_item, only: %i[update image remove_image]

  def index
    CatalogParameters.ensure!(Current.account)
    items = filtered.ordered
    page = [params[:page].to_i, 1].max
    render json: {
      catalog_items: items.offset((page - 1) * PER_PAGE).limit(PER_PAGE).map { |item| item_json(item) },
      meta: { count: items.count, page: page, per_page: PER_PAGE, can_edit: access_grant.catalog_writable? }
    }
  end

  def categories
    categories = Current.account.catalog_categories.where(active: true).includes(:parent).map(&:path).sort_by(&:downcase)
    render json: { categories: categories }
  end

  def create
    item = catalog.new(item_params)
    item.save ? render(json: { catalog_item: item_json(item) }, status: :created) : render_errors(item)
  end

  def update
    @item.update(item_params) ? render(json: { catalog_item: item_json(@item) }) : render_errors(@item)
  end

  def image
    return render json: { error: [I18n.t('catalog_items.image.invalid')] }, status: :unprocessable_entity if params[:image].blank?

    file = params[:image]
    ok_type = CatalogItem::IMAGE_TYPES.include?(file.content_type.to_s) && file.size <= CatalogItem::MAX_IMAGE
    return render json: { error: [I18n.t('catalog_items.image.invalid')] }, status: :unprocessable_entity unless ok_type

    @item.image.attach(file)
    render json: { catalog_item: item_json(@item) }
  end

  def remove_image
    @item.image.purge if @item.image.attached?
    render json: { catalog_item: item_json(@item) }
  end

  def export
    csv = CSV.generate do |rows|
      rows << CSV_COLUMNS
      catalog.ordered.includes(:tax_rate).each { |item| rows << csv_row(item) } # rubocop:disable Rails/FindEach -- por nombre
    end
    send_data csv, filename: 'catalogo.csv', type: 'text/csv'
  end

  def import
    return render json: { error: I18n.t('catalog_items.import.no_file') }, status: :unprocessable_entity if params[:file].blank?

    CatalogParameters.ensure!(Current.account)
    result = import_rows(CSV.parse(params[:file].read.force_encoding('UTF-8').delete_prefix('﻿'), headers: true))
    render json: result
  rescue CSV::MalformedCSVError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def catalog
    Current.account.catalog_items
  end

  def filtered
    items = catalog.search(params[:q])
    items = items.where(kind: params[:kind]) if CatalogItem.kinds.key?(params[:kind].to_s)
    items = by_category(items)
    case params[:active].to_s
    when 'all' then items
    when 'false' then items.where(active: false)
    else items.active
    end
  end

  def set_item
    @item = catalog.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: I18n.t('catalog_items.not_found') }, status: :not_found
  end

  def item_params
    permitted = params.require(:catalog_item).permit(:name, :sku, :kind, :category, :unit, :price, :currency, :description, :active,
                                                     :catalog_category_id, :catalog_unit_id, :tax_rate_id, :price_includes_tax, :sat_code,
                                                     withholding_rate_ids: [])
    permitted[:cost] = params[:catalog_item][:cost] if access_grant.can?(:see_amounts) && params[:catalog_item].key?(:cost)
    permitted
  end

  def check_read_access
    render_access_denied unless access_grant.catalog_readable?
  end

  def check_write_access
    render_access_denied unless access_grant.catalog_writable?
  end

  def render_errors(item)
    render json: { error: item.errors.full_messages }, status: :unprocessable_entity
  end

  def item_json(item)
    {
      id: item.id, name: item.name, sku: item.sku, kind: item.kind, category: item.category, unit: item.unit,
      price: item.price.to_f, currency: item.currency, description: item.description, active: item.active,
      cost: (item.cost&.to_f if access_grant.can?(:see_amounts)),
      image_url: (url_for(item.image) if item.image.attached?)
    }.merge(parameters_json(item))
  end

  # Productos y servicios › Parámetros: sus listas, y el impuesto y precio con que entra a una partida.
  def parameters_json(item)
    { catalog_category_id: item.catalog_category_id, catalog_unit_id: item.catalog_unit_id, tax_rate_id: item.tax_rate_id,
      price_includes_tax: item.price_includes_tax, sat_code: item.sat_code, tax_name: item.effective_tax_rate&.name,
      tax_percent: item.quote_tax_percent.to_f, quote_price: item.quote_unit_price.to_f,
      withholding_rate_ids: item.withholding_rate_ids, withholdings: item.quote_withholdings }
  end

  def csv_row(item)
    cost = access_grant.can?(:see_amounts) ? item.cost&.to_f : nil
    [item.sku, item.name, item.kind, item.category, item.unit, item.price.to_f, item.currency, cost,
     item.description, item.active ? 'si' : 'no', item.tax_rate&.name, item.price_includes_tax ? 'si' : 'no', item.sat_code,
     item.withholding_rates.map(&:name).join('; ')]
  end

  # Cada fila crea o actualiza (por clave; sin clave, por nombre). Devuelve el conteo
  # y los errores por número de fila para que el usuario los corrija.
  def import_rows(table)
    result = { created: 0, updated: 0, errors: [] }
    table.each.with_index(2) do |row, line|
      attrs = row_attributes(row)
      item = find_for_import(attrs) || catalog.new
      created = item.new_record?
      if item.update(attrs)
        result[created ? :created : :updated] += 1
      else
        result[:errors] << { line: line, error: item.errors.full_messages.join(', ') }
      end
    end
    result
  end

  TEXT_COLUMNS = { sku: 'clave', name: 'nombre', category: 'categoria', unit: 'unidad', currency: 'moneda',
                   description: 'descripcion' }.freeze

  def row_attributes(row)
    value = ->(key) { row[key] || row[key.capitalize] }
    attrs = TEXT_COLUMNS.transform_values { |column| value.call(column) }
    attrs[:kind] = CatalogItem.kind_from(value.call('tipo')) || 'product'
    attrs[:price] = money(value.call('precio')) || 0
    attrs[:cost] = money(value.call('costo')) if access_grant.can?(:see_amounts)
    attrs.merge(tax_attributes(value))
  end

  # impuesto (nombre o porcentaje; vacío = el de por omisión), precio_con_impuesto (si/no), clave_sat.
  # Las columnas que no vienen en el archivo no cambian nada.
  def tax_attributes(value)
    attrs = { active: %w[no false 0 inactivo].exclude?(value.call('activo').to_s.strip.downcase) }
    attrs[:sat_code] = value.call('clave_sat') unless value.call('clave_sat').nil?
    attrs[:price_includes_tax] = YES.include?(value.call('precio_con_impuesto').to_s.strip.downcase) unless value.call('precio_con_impuesto').nil?
    attrs.merge(rate_attributes(value))
  end

  # impuesto (nombre o porcentaje) y retenciones («Ret. IVA 10.67 %; Ret. ISR 10 %»), si vienen en el archivo.
  def rate_attributes(value)
    rates = Current.account.tax_rates
    attrs = {}
    attrs[:tax_rate_id] = rates.matching(value.call('impuesto'))&.id unless value.call('impuesto').nil?
    attrs[:withholding_rate_ids] = rates.withholding_ids_for(value.call('retenciones')) unless value.call('retenciones').nil?
    attrs
  end

  YES = %w[si sí yes true 1 x].freeze

  # Por categoría: la del texto (como antes) o la de la lista con sus subcategorías.
  def by_category(items)
    items = items.where(category: params[:category]) if params[:category].present?
    return items if params[:category_id].blank?

    category = Current.account.catalog_categories.find_by(id: params[:category_id])
    items.where(catalog_category_id: category ? category.self_and_child_ids : [])
  end

  def money(raw)
    raw.to_s.delete(',$ ').presence
  end

  def find_for_import(attrs)
    return catalog.find_by(sku: attrs[:sku].strip) if attrs[:sku].present?

    catalog.find_by('LOWER(name) = ?', attrs[:name].to_s.strip.downcase)
  end
end
