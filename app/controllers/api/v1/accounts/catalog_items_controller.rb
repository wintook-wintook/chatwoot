# Plan-Catalogo-Cotizaciones C1 — Ventas › Catálogo.
#
#   GET   /catalog_items            ?q= &kind= &category= &active=true|false|all &page=
#   GET   /catalog_items/categories las categorías usadas (para sugerir)
#   GET   /catalog_items/export     CSV
#   POST  /catalog_items/import     CSV (file): actualiza por clave, si no, por nombre
#   POST  /catalog_items            PATCH /catalog_items/:id
#
# Lo consulta quien tiene Ventas o Servicio; lo edita Ventas con «Todo» (o el
# Administrador). El costo solo viaja con «Ver montos». No se borra: se desactiva.
class Api::V1::Accounts::CatalogItemsController < Api::V1::Accounts::BaseController
  require 'csv'

  PER_PAGE = 50
  CSV_COLUMNS = %w[clave nombre tipo categoria unidad precio moneda costo descripcion activo].freeze

  before_action :check_read_access
  before_action :check_write_access, only: %i[create update import]
  before_action :set_item, only: %i[update]

  def index
    items = filtered.ordered
    page = [params[:page].to_i, 1].max
    render json: {
      catalog_items: items.offset((page - 1) * PER_PAGE).limit(PER_PAGE).map { |item| item_json(item) },
      meta: { count: items.count, page: page, per_page: PER_PAGE, can_edit: access_grant.catalog_writable? }
    }
  end

  def categories
    render json: { categories: catalog.where.not(category: nil).distinct.order(:category).pluck(:category) }
  end

  def create
    item = catalog.new(item_params)
    item.save ? render(json: { catalog_item: item_json(item) }, status: :created) : render_errors(item)
  end

  def update
    @item.update(item_params) ? render(json: { catalog_item: item_json(@item) }) : render_errors(@item)
  end

  def export
    csv = CSV.generate do |rows|
      rows << CSV_COLUMNS
      catalog.ordered.each { |item| rows << csv_row(item) }
    end
    send_data csv, filename: 'catalogo.csv', type: 'text/csv'
  end

  def import
    return render json: { error: I18n.t('catalog_items.import.no_file') }, status: :unprocessable_entity if params[:file].blank?

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
    items = items.where(category: params[:category]) if params[:category].present?
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
    permitted = params.require(:catalog_item).permit(:name, :sku, :kind, :category, :unit, :price, :currency, :description, :active)
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
      cost: (item.cost&.to_f if access_grant.can?(:see_amounts))
    }
  end

  def csv_row(item)
    cost = access_grant.can?(:see_amounts) ? item.cost&.to_f : nil
    [item.sku, item.name, item.kind, item.category, item.unit, item.price.to_f, item.currency, cost,
     item.description, item.active ? 'si' : 'no']
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
    attrs[:active] = %w[no false 0 inactivo].exclude?(value.call('activo').to_s.strip.downcase)
    attrs
  end

  def money(raw)
    raw.to_s.delete(',$ ').presence
  end

  def find_for_import(attrs)
    return catalog.find_by(sku: attrs[:sku].strip) if attrs[:sku].present?

    catalog.find_by('LOWER(name) = ?', attrs[:name].to_s.strip.downcase)
  end
end
