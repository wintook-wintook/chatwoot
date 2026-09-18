# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — HERRAMIENTAS SOBRE UN ENTRENAMIENTO (fase E de PROMPT STUDIO)
# ================================================================================
# POST /api/v1/accounts/:account_id/contact_trackings/assistant/suggested_tests
#   Mensajes de cliente escritos por el modelo, pasados por el clasificador real, con
#   su veredicto. Ver SuggestedTests. Avisa el avance en `turn_id` (ver TurnProgress).
#
# POST …/assistant/optimize
#   Hallazgos (redundante, contradicción, simplificable, sobrante) y un Entrenamiento
#   propuesto que no toca el ruteo, no borra secciones y marca las reglas que pierde.
#   Nunca se aplica solo. Ver Optimizer.
#
# POST …/assistant/explain
#   Qué hace un fragmento seleccionado: lo que lee el motor (hecho) y la lectura del
#   modelo (interpretación). Ver Explainer.
#
# POST …/assistant/proofread
#   El Objetivo o el Contexto del agente con la redacción y la ortografía corregidas,
#   sin tocar ni un dato. Ver Proofreader.
#
# POST …/assistant/transcribe  (multipart: audio)
#   Lo que la persona dictó, en texto, para el cuadro de mensaje. Ver Transcriber.
#
# Aparte de AssistantController: son herramientas que se aplican a un borrador ya
# escrito, no parte de la conversación, y aquel controlador ya estaba en su tope de
# largo. Mismo permiso: el Entrenamiento define cómo le contesta el bot a los clientes.
# ================================================================================

class Api::V1::Accounts::ContactTrackings::AssistantToolsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :require_draft, except: [:transcribe, :proofread]

  def suggested_tests
    avance = ContactTrackings::Assistant::TurnProgress.new(Current.account, Current.user, params[:turn_id])
    render json: ContactTrackings::Assistant::SuggestedTests
      .new(Current.account, draft: params[:draft], inbox: inbox, progress: avance.method(:update)).call
  end

  def optimize
    avance = ContactTrackings::Assistant::TurnProgress.new(Current.account, Current.user, params[:turn_id])
    result = ContactTrackings::Assistant::Optimizer
             .new(Current.account, draft: params[:draft], inbox: inbox, progress: avance.method(:update)).call
    render_result(result)
  end

  def explain
    result = ContactTrackings::Assistant::Explainer
             .new(Current.account, draft: params[:draft], excerpt: params[:excerpt], inbox: inbox).call
    render_result(result)
  end

  def proofread
    result = ContactTrackings::Assistant::Proofreader
             .new(Current.account, text: params[:text], kind: params[:kind], inbox: inbox).call
    render_result(result)
  end

  def transcribe
    render_result(ContactTrackings::Assistant::Transcriber.new(Current.account, file: params[:audio]).call)
  end

  private

  # `lost`: lo que una corrección de redacción intentó cambiar y no podía (ver
  # Proofreader). Viaja con el error para que la pantalla diga qué fue.
  def render_result(result)
    return render json: result.slice(:error, :lost), status: :unprocessable_entity if result[:error]

    render json: result
  end

  def require_draft
    render json: { error: 'blank_draft' }, status: :unprocessable_entity if params[:draft].blank?
  end

  def inbox
    return nil if params[:inbox_id].blank?

    Current.account.inboxes.find_by(id: params[:inbox_id])
  end

  def check_authorization
    render json: { error: I18n.t('errors.unauthorized') }, status: :unauthorized unless Current.account_user&.administrator?
  end
end
