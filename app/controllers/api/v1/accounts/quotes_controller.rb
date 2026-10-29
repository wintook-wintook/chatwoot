# Plan-Catalogo-Cotizaciones V1 — Ventas › Cotizaciones.
#
#   GET    /quotes            ?status=open|draft|sent|won|lost|postponed|cancelled|expired|all
#                             &q= &assignee_id= &contact_id= &opportunity_id= &origin_ticket_id= &page=
#   GET    /quotes/summary    métricas (enviadas, % de aceptación, monto en juego, vencidas, por vendedor)
#   POST   /quotes            PATCH /quotes/:id (solo borrador o enviada)   DELETE (solo borrador)
#   POST   /quotes/:id/transition        { to, reason_id, note, postponed_until }
#   POST   /quotes/:id/new_version       la anterior queda cancelada («Reemplazada por vN»)
#   POST   /quotes/:id/link_opportunity  { opportunity_id } o { create: true }; sin ninguno la quita
#                                        (no si la empresa la exige). Ya cerrada (ganada, perdida,
#                                        cancelada) no se cambia: su monto y resultado ya pasaron.
#   POST   /quotes/:id/deliver           manda el enlace al cliente por su última conversación
#
# Alcance por rol: Access::Grant#quotes. La puede hacer quien tiene Ventas, o
# quien puede trabajar el caso del que sale (el técnico cotiza trabajo adicional).
class Api::V1::Accounts::QuotesController < Api::V1::Accounts::BaseController
  PER_PAGE = 25
  ITEM_FIELDS = %i[catalog_item_id description kind unit quantity unit_price discount_percent tax_percent].freeze

  before_action :check_access
  before_action :set_quote, except: %i[index create summary]
  before_action :check_editable, only: %i[update]

  def index
    quotes = filtered.includes(:contact, :assignee, :opportunity, :origin_ticket, :outcome_reason)
                     .order(created_at: :desc)
    page = [params[:page].to_i, 1].max
    render json: { quotes: quotes.offset((page - 1) * PER_PAGE).limit(PER_PAGE).map { |q| quote_json(q) },
                   meta: { count: quotes.count, page: page, per_page: PER_PAGE, counts: status_counts } }
  end

  def summary
    render json: Quotes::Summary.new(visible_quotes).build
  end

  def show
    render json: { quote: quote_json(@quote, full: true) }
  end

  def create
    origin = find_ticket(quote_params[:origin_ticket_id])
    return render_access_denied unless can_create?(origin)

    quote = Quote.transaction { build_quote(origin) }
    render json: { quote: quote_json(quote, full: true) }, status: :created
  rescue ActiveRecord::RecordInvalid, Quotes::Builder::Error => e
    render_error(e.respond_to?(:record) ? e.record.errors.full_messages : e.message)
  end

  def update
    Quote.transaction do
      @quote.update!(quote_params.except(:contact_id, :origin_ticket_id, :opportunity_id))
      replace_items(@quote) if params.key?(:items)
      @quote.recalculate!
    end
    render json: { quote: quote_json(@quote.reload, full: true) }
  rescue ActiveRecord::RecordInvalid => e
    render_error(e.record.errors.full_messages)
  end

  def destroy
    return render_error(I18n.t('quotes.errors.only_drafts')) unless @quote.draft?

    @quote.destroy!
    head :no_content
  end

  def transition
    result = Quotes::StatusService.new(@quote, actor: current_user)
                                  .apply!(params[:to], reason_id: params[:reason_id], note: params[:note],
                                                       postponed_until: params[:postponed_until])
    render json: { quote: quote_json(result[:quote].reload, full: true), prompt: result[:prompt] }
  rescue Quotes::StatusService::Error, ActiveRecord::RecordInvalid, RuntimeError => e
    render_error(e.message)
  end

  def new_version
    copy = Quotes::Builder.new(Current.account, current_user).new_version(@quote)
    render json: { quote: quote_json(copy, full: true) }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_error(e.record.errors.full_messages)
  end

  def link_opportunity
    return render_error(I18n.t('quotes.errors.opportunity_locked')) if Quote::CLOSED_STATUSES.include?(@quote.status)

    opportunity = chosen_opportunity
    return render_error(I18n.t('quotes.errors.opportunity_required')) if opportunity.nil? && opportunity_required?

    @quote.update!(opportunity: opportunity)
    render json: { quote: quote_json(@quote.reload, full: true) }
  rescue ActiveRecord::RecordNotFound
    render_error(I18n.t('quotes.errors.opportunity_not_found'))
  rescue Quotes::Builder::Error, ActiveRecord::RecordInvalid => e
    render_error(e.message)
  end

  def deliver
    message = Quotes::Delivery.new(@quote, current_user).deliver!
    render json: { quote: quote_json(@quote.reload, full: true), message_id: message.id }
  rescue Quotes::Delivery::Error => e
    render_error(e.message)
  end

  private

  # create: true → una nueva; opportunity_id → una del cliente; nada → quitarla.
  def chosen_opportunity
    return Quotes::Builder.new(Current.account, current_user).create_opportunity(@quote) if
      ActiveModel::Type::Boolean.new.cast(params[:create])
    return if params[:opportunity_id].blank?

    account_case_tickets.commercial.find(params[:opportunity_id])
  end

  def opportunity_required?
    CaseSetting.for_account(Current.account).quotes_require_opportunity
  end

  def check_access
    render_access_denied unless access_grant.case_area_allowed?
  end

  def visible_quotes
    access_grant.quotes(Current.account.quotes)
  end

  def set_quote
    @quote = visible_quotes.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: I18n.t('quotes.errors.not_found') }, status: :not_found
  end

  def check_editable
    render_error(I18n.t('quotes.errors.not_editable')) unless @quote.editable?
  end

  def can_create?(origin)
    return access_grant.case_writable?(origin) if origin

    access_grant.writable?(:sales)
  end

  def find_ticket(id)
    id.present? ? account_case_tickets.find_by(id: id) : nil
  end

  def build_quote(origin)
    builder = Quotes::Builder.new(Current.account, current_user)
    quote = builder.create!(quote_params.except(:origin_ticket_id, :opportunity_id).merge(
                              origin_ticket: origin,
                              opportunity: find_ticket(quote_params[:opportunity_id])&.then { |t| t if t.commercial? }
                            ), create_opportunity: ActiveModel::Type::Boolean.new.cast(params[:create_opportunity]))
    replace_items(quote) if params.key?(:items)
    quote.recalculate!
    quote
  end

  def replace_items(quote)
    quote.items.destroy_all
    Array(params[:items]).each_with_index do |raw, index|
      attrs = raw.permit(*ITEM_FIELDS).to_h
      attrs[:catalog_item_id] = Current.account.catalog_items.where(id: attrs[:catalog_item_id]).pick(:id)
      quote.items.create!(attrs.merge(account: Current.account, position: index))
    end
  end

  LINK_FILTERS = %i[assignee_id contact_id opportunity_id origin_ticket_id organization_id].freeze

  def filtered
    quotes = filter_status(visible_quotes)
    LINK_FILTERS.each { |key| quotes = quotes.where(key => params[key]) if params[key].present? }
    search(quotes)
  end

  def filter_status(quotes)
    case params[:status].to_s
    when '', 'open' then quotes.live
    when 'all' then quotes
    when 'expired' then quotes.expired
    else Quote.statuses.key?(params[:status]) ? quotes.where(status: params[:status]) : quotes
    end
  end

  def search(quotes)
    term = params[:q].to_s.strip
    return quotes if term.blank?

    number = term.gsub(/\D/, '').to_i
    by_contact = quotes.joins(:contact).where('contacts.name ILIKE ?', "%#{Quote.sanitize_sql_like(term)}%")
    number.positive? ? by_contact.or(quotes.joins(:contact).where(number: number)) : by_contact
  end

  def status_counts
    counts = visible_quotes.group(:status).count
    Quote.statuses.keys.index_with { |status| counts[status] || 0 }.merge('expired' => visible_quotes.expired.count)
  end

  def quote_params
    params.require(:quote).permit(:contact_id, :organization_id, :assignee_id, :opportunity_id, :origin_ticket_id, :currency,
                                  :valid_until, :terms, :notes)
  end

  def render_error(message)
    render json: { error: Array(message).join(', ') }, status: :unprocessable_entity
  end

  def quote_json(quote, full: false)
    Quotes::Serializer.new(quote, grant: access_grant).as_json(full: full)
  end
end
