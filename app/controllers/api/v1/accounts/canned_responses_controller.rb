class Api::V1::Accounts::CannedResponsesController < Api::V1::Accounts::BaseController
  before_action :fetch_canned_response, only: [:update, :destroy]

  def index
    render json: canned_responses
  end

  def create
    @canned_response = Current.account.canned_responses.new(canned_response_params)
    @canned_response.save!
    render json: @canned_response
  end

  def update
    @canned_response.update!(canned_response_params)
    render json: @canned_response
  end

  def destroy
    @canned_response.destroy!
    head :ok
  end

  private

  def fetch_canned_response
    @canned_response = Current.account.canned_responses.find(params[:id])
  end

  # def canned_response_params
  #   params.require(:canned_response).permit(:short_code, :content)
  # end

  # proyecto@predefinidas_prompt — `menu`, `opcion`, `content_full`, `url_content` y
  # `url_short_code` son del bot viejo: sus columnas existen en la base de donde salió,
  # pero no en todas (en chatwoot_dev no). Aceptarlos a ciegas hacía reventar el guardado
  # con UnknownAttributeError, así que se quedan solo los que la tabla tiene de verdad.
  def canned_response_params
    params.require(:canned_response).permit(
      :short_code,
      :content,
      :content_prompts,
      :content_is_prompt,
      :menu,
      :opcion,
      :content_full,
      :url_content,
      :url_short_code
    ).slice(*CannedResponse.column_names)
  end

  def canned_responses
    if params[:search]
      Current.account.canned_responses
             .where('short_code ILIKE :search OR content ILIKE :search', search: "%#{params[:search]}%")
             .order_by_search(params[:search])

    else
      Current.account.canned_responses
    end
  end
end
