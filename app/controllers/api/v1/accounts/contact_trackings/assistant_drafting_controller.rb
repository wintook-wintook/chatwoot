# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — CONVERSAR PARA ARMAR UN AGENTE DESDE CERO
# ================================================================================
# POST /api/v1/accounts/:account_id/contact_trackings/assistant/drafting_chat
#   { messages: [...], instructions: "el .md hasta ahora", routes: "el boceto", session_id }
#   → { reply, instructions, changed, routes, tools_used, session_id, session }
#   Un turno de la conversación que llena las instrucciones iniciales (DraftingChat).
#   Se usa mientras no hay Entrenamiento; con uno en pantalla, el chat edita
#   (…/assistant/interview). Guarda el hilo y las instrucciones en la conversación
#   (TrackingAssistantSession), para retomarla desde «En construcción».
#
# Aparte de AssistantController, que ya está en su tope de largo. Mismo permiso.
#
# proyecto@crear_agente_conversando FR: con `custom_attributes['assistant_tools']` en la
# cuenta, el modelo consulta y prueba las fuentes antes de proponer (AssistantTools), y
# lleva el boceto de rutas probadas (D10), que se guarda en la conversación
# (proposal['boceto']). No es una bandera de funciones: features.yml ya usa 63 de los
# 63 bits de feature_flags.
#
# proyecto@crear_agente_conversando F3: el turno también lleva y devuelve `fields`, lo de
# las pestañas Definición, Variables y Datos fijos (ver DraftingFields). Se guardan en
# proposal: objective y ai_context (las columnas del agente, las mismas que llena el
# modal de Definición) y 'variables' / 'datos_fijos' (el texto de su sección).
#
# PATCH …/assistant/drafting_chat/fields  { session_id, fields }
#   Lo corregido a mano en una pestaña, sin gastar un turno. Sin conversación todavía, la
#   pantalla lo guarda en memoria y viaja con el siguiente mensaje.
# ================================================================================

class Api::V1::Accounts::ContactTrackings::AssistantDraftingController < Api::V1::Accounts::BaseController
  ALLOWED_ROLES = %w[user assistant].freeze
  MAX_TESTS = 30
  FIELD_KEYS = ContactTrackings::Assistant::DraftingFields::KEYS

  before_action :check_authorization

  def create
    result = turn
    return render json: { error: result[:error] }, status: :unprocessable_entity if result[:error]

    sesion = record(result)
    render json: result.slice(:reply, :instructions, :changed, :routes, :tools_used, :fields)
                       .merge(tests: sesion&.proposal.to_h.fetch('pruebas', result[:tests]),
                              session_id: sesion&.id, session: session_meta(sesion))
  end

  def fields
    sesion = TrackingAssistantSession.find_by(id: params[:session_id], account: Current.account)
    return render json: { error: 'not_found' }, status: :not_found if sesion.nil?

    sesion.update!(proposal: sesion.proposal.to_h.merge(fields_param(blanks: true)))
    render json: { fields: sesion.proposal.slice(*FIELD_KEYS) }
  end

  private

  def messages
    Array(params[:messages]).map { |m| m.permit(:role, :content).to_h }
                            .select { |m| ALLOWED_ROLES.include?(m['role']) && m['content'].present? }
  end

  # El turno, con las pestañas completas: las que mandó la pantalla y encima lo que cambió.
  def turn
    result = ContactTrackings::Assistant::DraftingChat
             .new(Current.account, messages: messages, instructions: params[:instructions], tools: tools?,
                                   so_far: { routes: params[:routes], fields: fields_param }).call
    result[:error] ? result : result.merge(fields: fields_param.merge(result[:fields].to_h))
  end

  # blanks: al corregir a mano, vaciar una pestaña es una corrección; en un turno, lo
  # que no viene es que no cambió.
  def fields_param(blanks: false)
    crudo = params[:fields].respond_to?(:permit) ? params[:fields].permit(*FIELD_KEYS).to_h : {}
    limpio = crudo.slice(*FIELD_KEYS).transform_values { |v| v.to_s.strip }
    blanks ? limpio : limpio.compact_blank
  end

  # Que no se pueda guardar el hilo no le cuesta la respuesta a la persona.
  def record(result)
    sesion = TrackingAssistantSession.find_by(id: params[:session_id], account: Current.account) if params[:session_id].present?
    sesion ||= TrackingAssistantSession.new(account: Current.account, user: Current.user)
    turnos = messages + [{ 'role' => 'assistant', 'content' => result[:reply] }]
    sesion.record_turn(messages: turnos, instructions: result[:instructions], proposal: proposal_for(sesion, result))
    sesion
  rescue StandardError => e
    Rails.logger.error("[Asistente] no se pudo guardar la conversación: #{e.message}")
    nil
  end

  # El boceto (D10), las pruebas (FD) y las pestañas (F3) de la conversación, sin pisar lo
  # demás de proposal.
  # Una frase probada otra vez se queda con su último resultado.
  def proposal_for(sesion, result)
    return nil if result[:routes].blank? && result[:tests].blank? && result[:fields].blank?

    sesion.proposal.to_h.merge({ 'boceto' => result[:routes], 'pruebas' => merged_tests(sesion, result[:tests]) }.compact_blank)
          .merge(result[:fields].to_h)
  end

  def merged_tests(sesion, nuevas)
    previas = sesion.proposal.to_h.fetch('pruebas', [])
    (previas + Array(nuevas).map(&:stringify_keys)).reverse.uniq { |p| p['frase'].to_s.downcase }.reverse.last(MAX_TESTS)
  end

  def tools?
    ActiveModel::Type::Boolean.new.cast(Current.account.custom_attributes.to_h['assistant_tools']) || false
  end

  def session_meta(sesion)
    return nil if sesion.nil?

    { id: sesion.id, status: sesion.status, title: sesion.title,
      created_at: sesion.created_at, updated_at: sesion.updated_at }
  end

  def check_authorization
    render json: { error: I18n.t('errors.unauthorized') }, status: :unauthorized unless Current.account_user&.administrator?
  end
end
