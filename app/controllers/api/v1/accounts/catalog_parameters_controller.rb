# Productos y servicios › Parámetros — categorías (con subcategorías), impuestos y unidades de medida.
#
#   GET    /catalog_parameters                  las tres listas, con cuántos productos usan cada uno
#   POST   /catalog_parameters/:list            list = categories | taxes | units
#   PATCH  /catalog_parameters/:list/:id
#   DELETE /catalog_parameters/:list/:id        solo si nadie lo usa (si no: desactivarlo)
#
# Lo consulta quien ve el catálogo; lo cambia quien lo edita (Ventas en «Todo»).
class Api::V1::Accounts::CatalogParametersController < Api::V1::Accounts::BaseController
  LISTS = {
    'categories' => { assoc: :catalog_categories, fields: %i[name parent_id active] },
    'taxes' => { assoc: :tax_rates, fields: %i[name kind percent exempt is_default active] },
    'units' => { assoc: :catalog_units, fields: %i[name abbreviation sat_code active] }
  }.freeze

  before_action :check_read_access
  before_action :check_write_access, except: :index
  before_action :set_list, except: :index
  before_action :set_record, only: %i[update destroy]

  def index
    CatalogParameters.ensure!(Current.account)
    render json: payload
  end

  def create
    record = @scope.new(record_params)
    record.save ? render(json: payload, status: :created) : render_errors(record)
  end

  def update
    @record.update(record_params) ? render(json: payload) : render_errors(@record)
  end

  def destroy
    return render_error(I18n.t('catalog_parameters.in_use')) if @record.in_use?
    return render_error(I18n.t('catalog_parameters.default_tax')) if @record.try(:is_default?)

    @record.destroy ? render(json: payload) : render_errors(@record)
  end

  private

  def set_list
    list = LISTS[params[:list].to_s]
    return render(json: { error: I18n.t('catalog_parameters.not_found') }, status: :not_found) unless list

    @list = list
    @scope = Current.account.public_send(list[:assoc])
  end

  def set_record
    @record = @scope.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: I18n.t('catalog_parameters.not_found') }, status: :not_found
  end

  def record_params
    params.require(:record).permit(*@list[:fields])
  end

  def payload
    account = Current.account
    by_tax = items_by(:tax_rate_id).merge(withholding_counts) { |_id, a, b| a + b }
    {
      categories: account.catalog_categories.where(parent_id: nil).ordered.includes(:children)
                         .map { |c| category_json(c, items_by(:catalog_category_id)) },
      taxes: account.tax_rates.ordered.map { |t| tax_json(t, by_tax) },
      units: account.catalog_units.ordered.map { |u| unit_json(u, items_by(:catalog_unit_id)) },
      can_edit: access_grant.catalog_writable?
    }
  end

  def items_by(column)
    @items_by ||= {}
    @items_by[column] ||= Current.account.catalog_items.group(column).count
  end

  def category_json(category, counts)
    children = category.children.sort_by { |c| c.name.downcase }.map do |child|
      { id: child.id, name: child.name, path: child.path, active: child.active, parent_id: category.id, items: counts[child.id].to_i }
    end
    { id: category.id, name: category.name, path: category.path, active: category.active, parent_id: nil,
      items: counts[category.id].to_i, children: children }
  end

  def tax_json(tax, counts)
    { id: tax.id, name: tax.name, kind: tax.kind, percent: tax.percent.to_f, exempt: tax.exempt, is_default: tax.is_default,
      active: tax.active, items: counts[tax.id].to_i }
  end

  def unit_json(unit, counts)
    { id: unit.id, name: unit.name, abbreviation: unit.abbreviation, sat_code: unit.sat_code, active: unit.active,
      items: counts[unit.id].to_i }
  end

  # Cuántos productos llevan cada retención (van en un arreglo del producto).
  def withholding_counts
    Current.account.catalog_items.pluck(:withholding_rate_ids).flatten.tally
  end

  def check_read_access
    render_access_denied unless access_grant.catalog_readable?
  end

  def check_write_access
    render_access_denied unless access_grant.catalog_writable?
  end

  def render_error(message)
    render json: { error: [message] }, status: :unprocessable_entity
  end

  def render_errors(record)
    render json: { error: record.errors.full_messages }, status: :unprocessable_entity
  end
end
