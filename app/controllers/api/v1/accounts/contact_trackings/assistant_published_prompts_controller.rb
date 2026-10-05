# frozen_string_literal: true

# ================================================================================
# proyecto@publicar_prompts (F4) — LA GALERÍA DE PROMPTS PUBLICADOS, EN EL ASISTENTE
# ================================================================================
# Los prompts que otras cuentas publicaron se ven y se bajan SOLO desde el Asistente
# de Agentes IA (decisión del usuario, 05/10/2026): de ahí se parte para adecuarlos a
# la cuenta. Por eso estas rutas cuelgan de …/contact_trackings/assistant/ y piden lo
# mismo que el Asistente: administrador de la cuenta.
#
# GET …/assistant/published_prompts  (q, category opcionales)
#   Las publicaciones vigentes de TODAS las cuentas, sin el texto del prompt.
#   `own: true` marca las de la cuenta actual.
#
# GET …/assistant/published_prompts/:id
#   Una publicación vigente con el prompt completo, para leerla antes de bajarla.
#   Lista y detalle traen `files`: los archivos del agente que vienen incluidos (F6).
#   Despublicada o inexistente → 404.
#
# POST …/assistant/published_prompts/:id/install
#   Baja ESA publicación (una sola) como Agente IA nuevo de la cuenta y suma una
#   descarga. 201 con { tracking_template: { id, name }, requirements }; el Asistente
#   lo abre enseguida para adecuarlo. Despublicada → 404.
#
# El autor se muestra con el nombre de su cuenta, nunca con el correo (decisión D2).
# Plan: docs/publicar_prompts_plan.md
# ================================================================================

class Api::V1::Accounts::ContactTrackings::AssistantPublishedPromptsController < Api::V1::Accounts::BaseController
  LIMIT = 200
  SUMMARY_FIELDS = %i[id title description category version downloads_count published_at requirements].freeze
  DETAIL_FIELDS = %i[objective ai_context prompt keyword_actions settings].freeze

  before_action :check_authorization

  def index
    scope = PublishedPrompt.published.includes(:account, files: { file_attachment: :blob }).ordered
    scope = scope.search(params[:q]) if params[:q].present?
    scope = scope.by_category(params[:category]) if params[:category].present?
    render json: {
      published_prompts: scope.limit(LIMIT).map { |pub| summary_json(pub) },
      categories: PublishedPrompt::CATEGORIES
    }
  end

  def show
    pub = PublishedPrompt.published.find(params[:id])
    render json: summary_json(pub).merge(pub.as_json(only: DETAIL_FIELDS))
  end

  def install
    pub = PublishedPrompt.published.find(params[:id])
    template = PublishedPrompts::Installer.new(pub, Current.account, Current.user).install!
    render json: { tracking_template: template.slice(:id, :name), requirements: pub.requirements }, status: :created
  end

  private

  def check_authorization
    render json: { error: I18n.t('errors.unauthorized') }, status: :unauthorized unless Current.account_user&.administrator?
  end

  def summary_json(pub)
    pub.as_json(only: SUMMARY_FIELDS).merge(
      'author' => pub.account&.name,
      'own' => pub.account_id == Current.account.id,
      'files' => pub.files.map(&:summary) # F6: los archivos que trae
    )
  end
end
