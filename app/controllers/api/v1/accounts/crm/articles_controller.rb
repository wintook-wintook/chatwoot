# CrmZeus A1 — artículos (catalogados y no catalogados).
#
#   GET    /crm/articles          ?type=catalogued|uncatalogued &q= &status= &line_id= &page=
#   GET    /crm/articles/:id      con precios por lista e impuestos
#   POST   /crm/articles          { article: {..., prices_attributes: [...], tax_ids: [...], components_attributes: [...]} }
#   PATCH  /crm/articles/:id
#   DELETE /crm/articles/:id      no se borra si es componente de un kit
#   POST   /crm/articles/:id/catalog   no catalogado → catalogado
#   POST   /crm/articles/:id/image     multipart `image` · DELETE /crm/articles/:id/image
class Api::V1::Accounts::Crm::ArticlesController < Api::V1::Accounts::Crm::BaseController
  PER_PAGE = 50
  FIELDS = %i[catalog_status key name line_id unit_id status suspended_on suspension_reason is_stockable is_kit
              purchase_unit purchase_unit_content unit_weight notes].freeze
  COMPONENT_FIELDS = %i[id component_id quantity replaceable units_editable position _destroy].freeze

  before_action :check_sales_write_access, except: %i[index show]
  before_action :set_article, except: %i[index create]

  def index
    scope = filtered
    page = [params[:page].to_i, 1].max
    render json: {
      articles: scope.includes(*Crm::ArticleJson::LIST_INCLUDES).order(:name, :id)
                     .offset((page - 1) * PER_PAGE).limit(PER_PAGE).map { |article| Crm::ArticleJson.list_item(article) },
      meta: { count: scope.count, page: page, per_page: PER_PAGE, counts: type_counts, can_edit: access_grant.writable?(:sales) }
    }
  end

  def show
    render json: { article: detail_json }
  end

  def create
    @article = articles.new(article_params.merge(created_by: Current.user, updated_by: Current.user))
    return render_errors(@article) unless @article.save

    render json: { article: detail_json }, status: :created
  end

  def update
    return render_errors(@article) unless @article.update(article_params.merge(updated_by: Current.user))

    render json: { article: detail_json }
  end

  def destroy
    return render_errors(@article) unless @article.destroy

    head :ok
  end

  def catalog
    return render json: { message: 'Ya está catalogado' }, status: :unprocessable_entity if @article.catalogued?

    @article.catalog!(Current.user)
    render json: { article: detail_json }
  end

  def image
    if request.delete?
      @article.image.purge if @article.image.attached?
    else
      return render json: { message: 'Falta la imagen' }, status: :unprocessable_entity if params[:image].blank?

      # attach guarda al momento; si la imagen no pasa la validación no se guarda y devuelve nil.
      return render_errors(@article) unless @article.image.attach(params[:image])
    end
    render json: { article: detail_json }
  end

  private

  def articles
    Current.account.crm_articles
  end

  def filtered
    filters = { catalog_status: enum_param(:type, CrmArticle.catalog_statuses),
                status: enum_param(:status, CrmArticle.statuses), line_id: params[:line_id].presence }.compact
    articles.search(params[:q]).where(filters)
  end

  def enum_param(name, values)
    params[name].to_s if values.key?(params[name].to_s)
  end

  # Para las pestañas Catalogados / No catalogados / Todos (con la búsqueda aplicada, sin el tipo).
  def type_counts
    counts = articles.search(params[:q]).group(:catalog_status).count
    { catalogued: counts['catalogued'].to_i, uncatalogued: counts['uncatalogued'].to_i, all: counts.values.sum }
  end

  def set_article
    @article = articles.find(params[:id])
  end

  # Los impuestos llegan como ids de la cuenta; uno ajeno se rechaza (no se ignora en silencio).
  # Los componentes se validan en el modelo (de la cuenta, que no sean kits ni el mismo).
  def article_params
    permitted = params.require(:article).permit(*FIELDS, tax_ids: [],
                                                         prices_attributes: %i[id price_list_id price currency_id _destroy],
                                                         components_attributes: COMPONENT_FIELDS)
    permitted[:tax_ids] = Current.account.crm_taxes.find(permitted[:tax_ids].compact_blank).map(&:id) if permitted.key?(:tax_ids)
    permitted
  end

  def detail_json
    Crm::ArticleJson.detail(articles.includes(*Crm::ArticleJson::DETAIL_INCLUDES).find(@article.id))
  end
end
