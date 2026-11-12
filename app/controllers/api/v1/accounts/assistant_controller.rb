# frozen_string_literal: true

# Asistente (Dali) — el asistente conversacional de toda la plataforma.
#   GET    …/assistant                       → nombre del asistente y la conversación actual
#   POST   …/assistant/messages              { content, context: { page, case_id, contact_id,
#                                               conversation_id, organization_id }, tz }
#   POST   …/assistant/reset                 → archiva la conversación y empieza otra
#   POST   …/assistant/proposals/:id/confirm { payload } (los datos que el usuario dejó)
#   POST   …/assistant/proposals/:id/cancel
#   PATCH  …/assistant/settings              { name, model, analysis_model } (solo administradores)
#   POST   …/assistant/transcribe            { audio } → { text } (lo que dictó, para revisarlo y mandarlo)
#   POST   …/assistant/push_subscription { endpoint, p256dh, auth } → avisos en este teléfono: suscribe
#                                               (abren Dali) y prende «te asignaron» y «mensaje nuevo»
#   POST   …/assistant/mobile_link           → { url, expires_in } enlace de un solo uso (5 min) que entra
#                                               firmado al portal de Dali en el teléfono (el QR del perfil)
class Api::V1::Accounts::AssistantController < Api::V1::Accounts::BaseController
  MAX_CONTENT = 2000
  CONTEXT_KEYS = %w[page label case_id contact_id conversation_id organization_id].freeze

  before_action :set_thread, except: %i[settings transcribe mobile_link push_subscription]

  def show
    render json: thread_json
  end

  def messages
    content = params[:content].to_s.strip.first(MAX_CONTENT)
    return render json: { error: 'Escribe algo' }, status: :unprocessable_entity if content.blank?

    message = Assistant::Chat.new(thread: @thread, grant: access_grant, zone: zone, context: context_params).reply(content)
    render json: { message: message, messages: @thread.messages.last(2) }
  end

  def reset
    @thread.update!(archived: true)
    @thread = AssistantThread.create!(account: Current.account, user: current_user)
    render json: thread_json
  end

  def confirm
    proposal = find_proposal
    return if performed?

    payload = proposal['payload'].merge(params.fetch(:payload, {}).permit!.to_h)
    result = executor.call(proposal['type'], payload)
    @thread.update_proposal!(proposal['id'], status: 'done', payload: payload, result: result)
    render json: { proposal: @thread.find_proposal(proposal['id']) }
  rescue Assistant::Executor::Refused, ActiveRecord::RecordInvalid => e
    render json: { error: refusal_message(e) }, status: :unprocessable_entity
  end

  def cancel
    proposal = find_proposal
    return if performed?

    @thread.update_proposal!(proposal['id'], status: 'cancelled')
    render json: { proposal: @thread.find_proposal(proposal['id']) }
  end

  def settings
    return render json: { error: 'Solo un administrador cambia el nombre' }, status: :forbidden unless access_grant.admin?

    name = params.key?(:name) ? Assistant::Settings.update_name!(Current.account, params[:name]) : Assistant::Settings.name_for(Current.account)
    update_models if params.key?(:model) || params.key?(:analysis_model)
    render json: { name: name, models: Assistant::Settings.models(Current.account) }
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def transcribe
    audio = params[:audio]
    return render json: { error: 'Falta el audio' }, status: :unprocessable_entity unless audio.respond_to?(:tempfile)

    text = Assistant::Transcriber.new(account: Current.account).call(audio)
    return render json: { error: 'No se entendió el audio. Intenta de nuevo.' }, status: :unprocessable_entity if text.blank?

    render json: { text: text.first(MAX_CONTENT) }
  rescue Assistant::Transcriber::TooLarge
    render json: { error: 'La nota es muy larga: dicta en partes más cortas.' }, status: :unprocessable_entity
  end

  # Te asignaron, te escribieron en una tuya y te mencionaron (también en el chat interno; los
  # directos del chat interno avisan solos al teléfono: Notification::PushNotificationService).
  PUSH_TYPES = %i[push_conversation_assignment push_assigned_conversation_new_message push_conversation_mention].freeze

  def push_subscription
    keys = params.permit(:endpoint, :p256dh, :auth).to_h
    return render json: { error: 'Falta la suscripción del teléfono' }, status: :unprocessable_entity if keys.values.any?(&:blank?) || keys.size < 3

    NotificationSubscriptionBuilder.new(user: current_user, params: ActionController::Parameters.new(
      subscription_type: 'browser_push', subscription_attributes: keys.merge('dali' => true)
    ).permit!).perform
    setting = current_user.notification_settings.find_or_create_by!(account_id: Current.account.id)
    PUSH_TYPES.each { |flag| setting.public_send("#{flag}=", true) }
    setting.save!
    render json: { ok: true }
  end

  def mobile_link
    url = "#{current_user.generate_sso_link}&sso_account_id=#{Current.account.id}&redirect=dali"
    render json: { url: url, expires_in: 5.minutes.to_i }
  end

  private

  def set_thread
    @thread = AssistantThread.current_for(Current.account, current_user)
  end

  def find_proposal
    proposal = @thread.find_proposal(params[:id].to_s)
    return render(json: { error: 'Propuesta no encontrada' }, status: :not_found) unless proposal
    return render(json: { error: 'Esa propuesta ya no está pendiente' }, status: :unprocessable_entity) if proposal['status'] != 'pending'

    proposal
  end

  def executor
    Assistant::Executor.new(account: Current.account, user: current_user, grant: access_grant, zone: zone)
  end

  def refusal_message(error)
    error.respond_to?(:record) ? error.record.errors.full_messages.to_sentence : error.message
  end

  def zone
    ActiveSupport::TimeZone[params[:tz].to_s] || Time.zone
  end

  def context_params
    params.fetch(:context, {}).permit(*CONTEXT_KEYS).to_h
  end

  def update_models
    Assistant::Settings.update_models!(Current.account, model: params[:model], analysis_model: params[:analysis_model])
  end

  def thread_json
    chat = Assistant::Chat.new(thread: @thread, grant: access_grant, zone: zone)
    { name: Assistant::Settings.name_for(Current.account), available: chat.available?, messages: @thread.messages,
      starters: Assistant::Capabilities.starters(access_grant), shortcuts: Assistant::Capabilities.shortcuts(access_grant),
      models: (Assistant::Settings.models(Current.account) if access_grant.admin?) }.compact
  end
end
