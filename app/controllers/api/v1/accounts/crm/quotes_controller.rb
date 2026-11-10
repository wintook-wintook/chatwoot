# CrmZeus Q1 — cotizaciones a clientes y prospectos de CrmZeus.
#
#   GET   /crm/quotes                 ?view=pending|won_this_month|recent|all &organization_id= &created_by_id= &q= &page=
#   GET   /crm/quotes/new             ?organization_id=  borrador con los defaults del cliente y la serie del agente
#   GET   /crm/quotes/:id             con partidas (cada kit con sus componentes) y resumen de impuestos
#   POST  /crm/quotes                 { quote: {..., items: [{..., tax_ids: [], components: [...]}]} }
#   PATCH /crm/quotes/:id             la lista de partidas reemplaza a la guardada; solo en Pendiente
#   POST  /crm/quotes/calculate       mismos datos que el alta: regresa los importes sin guardar
#   POST  /crm/quotes/:id/status      { status: won|lost|cancelled|pending }
#   POST  /crm/quotes/:id/duplicate   borrador sin guardar con los mismos datos (como CRMZeus, en el navegador)
#
# Todos los de Ventas ven todas; edita y cambia el estatus quien tiene Ventas con escritura y es
# el creador o un administrador (decisión 4). No se borran: se cancelan. Los totales los pone el
# servidor; los que mande el navegador se ignoran.
class Api::V1::Accounts::Crm::QuotesController < Api::V1::Accounts::Crm::BaseController
  PER_PAGE = 50
  VIEWS = %w[pending won_this_month recent all].freeze
  NOT_OWNER_MESSAGE = 'Solo quien creó la cotización o un administrador la puede modificar'.freeze

  before_action :check_sales_write_access, except: %i[index show]
  before_action :set_quote, only: %i[show update status duplicate]
  before_action :check_owner, only: %i[update status]

  def index
    scope = filtered
    page = [params[:page].to_i, 1].max
    rows = scope.includes(*Crm::QuoteJson::LIST_INCLUDES).order(quote_date: :desc, id: :desc)
                .offset((page - 1) * PER_PAGE).limit(PER_PAGE)
    render json: {
      quotes: rows.map { |quote| Crm::QuoteJson.list_item(quote).merge(can_edit: can_edit?(quote)) },
      meta: { count: scope.count, page: page, per_page: PER_PAGE, view: view, can_create: series.present? }
    }
  end

  def show
    render json: { quote: detail_json }
  end

  def new
    quote = quotes.new(organization: params[:organization_id].presence && organizations.find(params[:organization_id]),
                       created_by: Current.user)
    render json: { quote: Crm::QuoteJson.draft(quote.fill_from_organization.preview), series: series_json }
  end

  def create
    @quote = Crm::QuoteForm.new(quotes.new(created_by: Current.user, updated_by: Current.user), quote_params).apply
    return render_errors(@quote) unless @quote.save

    render json: { quote: detail_json }, status: :created
  end

  def update
    Crm::QuoteForm.new(@quote, quote_params).apply
    @quote.updated_by = Current.user
    return render_errors(@quote) unless @quote.save

    render json: { quote: detail_json }
  end

  def calculate
    quote = Crm::QuoteForm.new(quotes.new(created_by: Current.user), quote_params, ids: false).apply
    quote.validate # corre el cálculo (before_validation); los errores van aparte, no detienen el cálculo
    render json: { quote: Crm::QuoteJson.totals(quote), errors: quote.errors.to_hash(true) }
  end

  def status
    @quote.change_status!(params.require(:status), Current.user)
    render json: { quote: detail_json }
  rescue ActiveRecord::RecordInvalid, ArgumentError
    render_errors(@quote)
  end

  def duplicate
    render json: { quote: Crm::QuoteJson.draft(Crm::QuoteCopy.new(@quote, Current.user).build), series: series_json }
  end

  private

  def quotes
    Current.account.crm_quotes
  end

  def organizations
    Current.account.crm_organizations
  end

  def set_quote
    @quote = quotes.includes(items: :item_taxes).find(params[:id])
  end

  def check_owner
    render json: { message: NOT_OWNER_MESSAGE }, status: :forbidden unless can_edit?(@quote)
  end

  def can_edit?(quote)
    access_grant.writable?(:sales) && (access_grant.admin? || quote.created_by_id == Current.user.id)
  end

  def view
    VIEWS.include?(params[:view]) ? params[:view] : 'pending'
  end

  # Filtros de la lista de CRMZeus: Pendientes (predet.) · Ganadas este mes · Todas de los
  # últimos 2 meses · Todas. Con organización o creador, además.
  def filtered
    scope = quotes.search(params[:q])
    scope = scope.where(organization_id: params[:organization_id]) if params[:organization_id].present?
    scope = scope.where(created_by_id: params[:created_by_id]) if params[:created_by_id].present?
    by_view(scope)
  end

  def by_view(scope)
    case view
    when 'pending' then scope.status_pending
    when 'won_this_month' then scope.status_won.where(status_changed_at: Time.current.all_month)
    when 'recent' then scope.where(quote_date: 2.months.ago.to_date..)
    else scope
    end
  end

  def series
    @series ||= Current.account.crm_quote_series.find_by(user: Current.user)
  end

  def series_json
    series && { series: series.series, next_folio: series.next_folio }
  end

  def quote_params
    Crm::QuoteForm.permit(params)
  end

  def detail_json
    Crm::QuoteJson.detail(quotes.includes(*Crm::QuoteJson::DETAIL_INCLUDES).find(@quote.id)).merge(can_edit: can_edit?(@quote))
  end
end
