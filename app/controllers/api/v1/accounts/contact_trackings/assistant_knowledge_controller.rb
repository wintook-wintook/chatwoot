# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — CONOCIMIENTO SUGERIDO (respuestas predefinidas)
# ================================================================================
# POST …/assistant/briefs/:id/knowledge
#   Las respuestas predefinidas que el agente de este encargo necesita, propuestas
#   (KnowledgeSuggestions). No crea nada.
#
# POST …/assistant/briefs/:id/knowledge/create  { group, items: [{ short_code, content }] }
#   Crea las elegidas como respuestas predefinidas de la cuenta (se vectorizan solas:
#   CannedResponse#sync_knowledge_embedding). Todas con el prefijo del grupo, que es lo
#   que busca @buscar_predefinidas(GRUPO). Nunca una con <PENDIENTE:>: el agente se la
#   citaría tal cual al cliente. Una que ya existe no se pisa.
#
# Aparte de AssistantBriefsController, que ya está en su tope de largo. Mismo permiso.
# ================================================================================

class Api::V1::Accounts::ContactTrackings::AssistantKnowledgeController < Api::V1::Accounts::BaseController
  MAX_ITEMS = 20
  MAX_CONTENT = 2000

  before_action :check_authorization
  before_action :fetch_brief

  def suggestions
    return render json: { error: 'not_ready' }, status: :unprocessable_entity unless @brief.ready?

    render json: ContactTrackings::Assistant::KnowledgeSuggestions.new(@brief, account: Current.account).call
  end

  def create
    grupo = params[:group].to_s.strip.upcase
    unless grupo.match?(ContactTrackings::Assistant::KnowledgeSuggestions::GROUP_RE)
      return render json: { error: 'invalid_group' }, status: :unprocessable_entity
    end

    resultado = items.each_with_object({ created: [], skipped: [], failed: [] }) { |item, acc| create_one(grupo, item, acc) }
    render json: resultado.merge(group: grupo)
  end

  private

  def items
    Array(params[:items]).first(MAX_ITEMS).map { |i| i.respond_to?(:permit) ? i.permit(:short_code, :content).to_h : {} }
  end

  def create_one(grupo, item, acc)
    codigo = with_group(grupo, item['short_code'])
    contenido = item['content'].to_s.strip
    problema = content_problem(contenido)
    return acc[:failed] << { short_code: codigo, error: problema } if problema
    return acc[:skipped] << codigo if Current.account.canned_responses.exists?(['LOWER(short_code) = LOWER(?)', codigo])

    Current.account.canned_responses.create!(short_code: codigo, content: contenido)
    acc[:created] << codigo
  rescue ActiveRecord::RecordInvalid => e
    acc[:failed] << { short_code: codigo, error: e.record.errors.full_messages.first }
  end

  def content_problem(contenido)
    return 'pending' if ContactTrackings::Assistant::PendingMarkers.pending?(contenido)

    'invalid' if contenido.blank? || contenido.size > MAX_CONTENT
  end

  # El prefijo es lo que hace que la ruta la encuentre: si se editó y se perdió, se repone.
  def with_group(grupo, codigo)
    limpio = codigo.to_s.squish.upcase
    limpio.start_with?("#{grupo} ") ? limpio : ContactTrackings::Assistant::KnowledgeSuggestions.group_prefixed(grupo, limpio)
  end

  def fetch_brief
    @brief = TrackingAgentBrief.find_by(id: params[:id], account: Current.account)
    render json: { error: 'not_found' }, status: :not_found if @brief.nil?
  end

  def check_authorization
    render json: { error: I18n.t('errors.unauthorized') }, status: :unauthorized unless Current.account_user&.administrator?
  end
end
