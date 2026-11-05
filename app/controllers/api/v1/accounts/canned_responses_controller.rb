# proyecto@respuestas_predefinidas R1: cada predefinida va con `embedding_state` (si está en
# la fuente de datos del agente, ver CannedResponse::EMBEDDING_STATES) y `embedding_error`.
#   POST …/canned_responses/:id/vectorize        [Vectorizar] / [Reintentar] de una
#   POST …/canned_responses/vectorize { ids }    varias a la vez, hasta MAX_VECTORIZE (D4)
# R2: GET …/canned_responses?page=N (+ q, state, prompt, sort, order, per_page) → la tabla,
#   paginada: { payload: [...], meta: { count, page, per_page } } (CannedResponseFinder).
#   Sin `page`, la lista completa como siempre: la usa el «/» del editor de mensajes.
class Api::V1::Accounts::CannedResponsesController < Api::V1::Accounts::BaseController
  MAX_VECTORIZE = 20

  before_action :fetch_canned_response, only: [:update, :destroy, :vectorize]
  MAX_DESTROY = 100

  def index
    return render json: with_embedding_state(canned_responses) if params[:page].blank?

    resultado = CannedResponseFinder.new(Current.account, params).perform
    render json: { payload: with_embedding_state(resultado[:records]),
                   meta: resultado.slice(:count, :page, :per_page, :summary) }
  end

  def create
    @canned_response = Current.account.canned_responses.new(canned_response_params)
    @canned_response.save!
    render json: with_embedding_state([@canned_response.reload]).first
  end

  def update
    @canned_response.update!(canned_response_params)
    render json: with_embedding_state([@canned_response.reload]).first
  end

  def vectorize
    @canned_response.queue_embedding!
    render json: with_embedding_state([@canned_response.reload]).first
  end

  # R2: eliminar varias desde la tabla.
  def destroy_many
    ids = Array(params[:ids]).map(&:to_i).uniq
    return render json: { error: 'too_many', max: MAX_DESTROY }, status: :unprocessable_entity if ids.size > MAX_DESTROY

    Current.account.canned_responses.where(id: ids).find_each(&:destroy!)
    head :ok
  end

  def vectorize_many
    ids = Array(params[:ids]).map(&:to_i).uniq
    return render json: { error: 'too_many', max: MAX_VECTORIZE }, status: :unprocessable_entity if ids.size > MAX_VECTORIZE

    registros = Current.account.canned_responses.where(id: ids).to_a
    registros.each(&:queue_embedding!)
    render json: with_embedding_state(registros.map(&:reload))
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

  # Dos consultas para toda la lista: si la cuenta tiene OpenAI y cuáles tienen vector.
  def with_embedding_state(registros)
    registros = registros.to_a
    con_clave = Current.account.hooks.exists?(app_id: 'openai', status: 'enabled')
    con_vector = KnowledgeItem.where(account_id: Current.account.id, source_type: 'canned_response', source_id: registros.map(&:id))
                              .where.not(embedding: nil).distinct.pluck(:source_id).to_set
    registros.map do |r|
      r.as_json.merge('embedding_state' => r.embedding_state(has_vector: con_vector.include?(r.id), has_key: con_clave))
    end
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
