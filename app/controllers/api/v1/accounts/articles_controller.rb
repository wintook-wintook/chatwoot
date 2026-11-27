class Api::V1::Accounts::ArticlesController < Api::V1::Accounts::BaseController
  before_action :portal
  before_action :check_authorization
  before_action :fetch_article, except: [:index, :create, :reorder]
  before_action :set_current_page, only: [:index]

  def index
    @portal_articles = @portal.articles
    @all_articles = @portal_articles.search(list_params)
    @articles_count = @all_articles.count

    @articles = if list_params[:category_slug].present?
                  @all_articles.order_by_position.page(@current_page)
                else
                  @all_articles.order_by_updated_at.page(@current_page)
                end
  end

  def show; end
  def edit; end

  def create
    @article = @portal.articles.create!(article_params)
    @article.associate_root_article(article_params[:associated_article_id])
    @article.draft!
    render json: { error: @article.errors.messages }, status: :unprocessable_entity and return unless @article.valid?
  end

  def update
    @article.update!(update_params) if params[:article].present?
    render json: { error: @article.errors.messages }, status: :unprocessable_entity and return unless @article.valid?
  end

  def destroy
    @article.destroy!
    head :ok
  end

  def reorder
    Article.update_positions(params[:positions_hash])
    head :ok
  end

  private

  def fetch_article
    @article = @portal.articles.find(params[:id])
  end

  def portal
    @portal ||= Current.account.portals.find_by!(slug: params[:portal_id])
  end

  def article_params
    params.require(:article).permit(
      :title, :slug, :position, :content, :description, :position, :category_id, :author_id, :associated_article_id, :status,
      meta: meta_keys
    )
  end

  # El meta recibido se combina con el guardado: la pantalla solo manda lo que edita y no debe
  # borrar el resto (en las guías de Dali, guide_key/areas/keywords/pages/sources).
  def update_params
    attrs = article_params
    attrs[:meta] = @article.meta.to_h.merge(attrs[:meta].to_h) if attrs.key?(:meta)
    attrs
  end

  def meta_keys
    keys = [:title, :description, { tags: [] }]
    Article.dali_portal?(@portal) ? keys + DaliGuideArticle::EDITABLE_META : keys
  end

  def list_params
    params.permit(:locale, :query, :page, :category_slug, :status, :author_id)
  end

  def set_current_page
    @current_page = params[:page] || 1
  end
end
