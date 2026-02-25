# KANBAN0725-CONTROLLER
class Api::V1::Accounts::ConversationsController < Api::V1::Accounts::BaseController
  include Events::Types
  include DateRangeHelper
  include HmacConcern

  before_action :conversation, except: [:index, :meta, :search, :create, :filter]
  before_action :inbox, :contact, :contact_inbox, only: [:create]

  # def index
  #   # ✅ AGREGAR FILTROS KANBAN ANTES DEL conversation_finder:
  #   if params[:kanban_type_process_id].present? || params[:kanban_process_id].present?
  #     # Aplicar filtros Kanban directamente
  #     conversations_query = Current.account.conversations
  #     conversations_query = conversations_query.where(kanban_type_process_id: params[:kanban_type_process_id]) if params[:kanban_type_process_id].present?
  #     conversations_query = conversations_query.where(kanban_process_id: params[:kanban_process_id]) if params[:kanban_process_id].present?
      
  #     @conversations = conversations_query.includes(:kanban_type_process, :kanban_process, :assignee, :contact, :inbox)
  #                                       .page(params[:page])
  #     @conversations_count = { all_count: conversations_query.count }
      
  #     # Renderizar directamente
  #     render json: {
  #       payload: @conversations.as_json(include: [:kanban_type_process, :kanban_process, :assignee, :contact, :inbox]),
  #       meta: @conversations_count
  #     }
  #   else
  #     # Usar el flujo normal existente
  #     result = conversation_finder.perform
  #     @conversations = result[:conversations]
  #     @conversations_count = result[:count]
  #   end
  # end


  def index
    result = conversation_finder.perform
    @conversations = result[:conversations]
    @conversations_count = result[:count]
  end

  def meta
    result = conversation_finder.perform
    @conversations_count = result[:count]
  end

  def search
    result = conversation_finder.perform
    @conversations = result[:conversations]
    @conversations_count = result[:count]
  end

  def attachments
    @attachments = @conversation.attachments
  end

  def show; end
  # def show
  #   render json: format_conversation_response(@conversation)
  # end

  # def show
  #   render json: @conversation.as_json(
  #     include: {
  #       kanban_type_process: {
  #         only: [:id, :process_name, :default, :is_system]
  #       },
  #       kanban_process: {
  #         only: [:id, :type_process_name, :position, :default, :is_system]
  #       }
  #     }
  #   )
  # end

  def create
    ActiveRecord::Base.transaction do
      @conversation = ConversationBuilder.new(params: params, contact_inbox: @contact_inbox).perform
      Messages::MessageBuilder.new(Current.user, @conversation, params[:message]).perform if params[:message].present?
    end
  end

  def update
    @conversation.update!(permitted_update_params)

    if @conversation.update(conversation_params)
      render json: @conversation
    else
      render json: { errors: @conversation.errors }, status: :unprocessable_entity
    end
  end

  # ✅ MÉTODO ORIGINAL MANTENIDO: update_kanban_process
  def update_kanban_process
    # @conversation = Current.account.conversations.find(params[:id])
    @conversation = Current.account.conversations.find_by!(display_id: params[:id])
    if @conversation.update(kanban_process_params)
      render json: @conversation.as_json(include: [:kanban_type_process, :kanban_process])
    else
      render json: { errors: @conversation.errors }, status: :unprocessable_entity
    end
  end

  # ✅ NUEVO MÉTODO MEJORADO: update_kanban_process_enhanced
  def update_kanban_process_enhanced
    Rails.logger.info "🔄 CONTROLLER: update_kanban_process_enhanced iniciado para conversación #{params[:id]}"
    Rails.logger.info "📊 CONTROLLER: Parámetros recibidos: #{kanban_process_params_enhanced}"

    @conversation = Current.account.conversations.find(params[:id])
    
    # Llamar al servicio para actualizar kanban
    result = update_conversation_kanban_fields(@conversation, kanban_process_params_enhanced)
    
    if result[:success]
      Rails.logger.info "✅ CONTROLLER: Conversación actualizada exitosamente"
      render json: format_conversation_response(@conversation)
    else
      Rails.logger.error "❌ CONTROLLER: Error: #{result[:errors]}"
      render json: { 
        error: 'Failed to update conversation kanban process',
        details: result[:errors]
      }, status: :unprocessable_entity
    end
  end

  # ✅ NUEVO MÉTODO: Actualizar solo kanban_process_id
  def update_kanban_process_only
    Rails.logger.info "🔄 CONTROLLER: update_kanban_process_only para conversación #{params[:id]}"
    
    @conversation = Current.account.conversations.find(params[:id])
    kanban_process_id = params[:kanban_process_id]
    
    # Validar que el kanban_process existe y pertenece a la cuenta
    if kanban_process_id.present?
      kanban_process = validate_kanban_process(kanban_process_id)
      return render_unauthorized_kanban_process unless kanban_process
    end

    # Actualizar solo el kanban_process_id
    if @conversation.update(kanban_process_id: kanban_process_id)
      Rails.logger.info "✅ CONTROLLER: kanban_process_id actualizado a #{kanban_process_id}"
      render json: format_conversation_response(@conversation)
    else
      Rails.logger.error "❌ CONTROLLER: Error actualizando: #{@conversation.errors.full_messages}"
      render json: { 
        error: 'Failed to update kanban process',
        details: @conversation.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # ✅ NUEVO MÉTODO: Actualización masiva de campos kanban
  def bulk_update_kanban
    Rails.logger.info "🔄 CONTROLLER: bulk_update_kanban para conversación #{params[:id]}"
    
    @conversation = Current.account.conversations.find(params[:id])
    
    # Parámetros que pueden venir en el request
    kanban_type_process_id = params[:kanban_type_process_id]
    kanban_process_id = params[:kanban_process_id]
    
    # Construir hash de actualización dinámicamente
    update_params = {}
    
    # Si se proporciona kanban_type_process_id
    if kanban_type_process_id.present?
      kanban_type_process = validate_kanban_type_process(kanban_type_process_id)
      return render_unauthorized_kanban_type_process unless kanban_type_process
      update_params[:kanban_type_process_id] = kanban_type_process_id
    end
    
    # Si se proporciona kanban_process_id
    if kanban_process_id.present?
      kanban_process = validate_kanban_process(kanban_process_id, kanban_type_process_id)
      return render_unauthorized_kanban_process unless kanban_process
      update_params[:kanban_process_id] = kanban_process_id
    end
    
    # Si ambos son nil, limpiar kanban
    if kanban_type_process_id.nil? && kanban_process_id.nil?
      update_params = { kanban_type_process_id: nil, kanban_process_id: nil }
    end

    Rails.logger.info "📊 CONTROLLER: Parámetros de actualización: #{update_params}"

    if @conversation.update(update_params)
      Rails.logger.info "✅ CONTROLLER: Actualización bulk exitosa"
      render json: format_conversation_response(@conversation)
    else
      Rails.logger.error "❌ CONTROLLER: Error en bulk update: #{@conversation.errors.full_messages}"
      render json: { 
        error: 'Failed to bulk update kanban fields',
        details: @conversation.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def filter
    result = ::Conversations::FilterService.new(params.permit!, current_user).perform
    @conversations = result[:conversations]
    @conversations_count = result[:count]
  rescue CustomExceptions::CustomFilter::InvalidAttribute,
         CustomExceptions::CustomFilter::InvalidOperator,
         CustomExceptions::CustomFilter::InvalidValue => e
    render_could_not_create_error(e.message)
  end

  def mute
    @conversation.mute!
    head :ok
  end

  def unmute
    @conversation.unmute!
    head :ok
  end

  def transcript
    render json: { error: 'email param missing' }, status: :unprocessable_entity and return if params[:email].blank?

    ConversationReplyMailer.with(account: @conversation.account).conversation_transcript(@conversation, params[:email])&.deliver_later
    head :ok
  end

  def toggle_status
    # FIXME: move this logic into a service object
    if pending_to_open_by_bot?
      @conversation.bot_handoff!
    elsif params[:status].present?
      set_conversation_status
      @status = @conversation.save!
    else
      @status = @conversation.toggle_status
    end
    assign_conversation if should_assign_conversation?
  end

  def pending_to_open_by_bot?
    return false unless Current.user.is_a?(AgentBot)

    @conversation.status == 'pending' && params[:status] == 'open'
  end

  def should_assign_conversation?
    @conversation.status == 'open' && Current.user.is_a?(User) && Current.user&.agent?
  end

  def toggle_priority
    @conversation.toggle_priority(params[:priority])
    head :ok
  end

  def toggle_typing_status
    typing_status_manager = ::Conversations::TypingStatusManager.new(@conversation, current_user, params)
    typing_status_manager.toggle_typing_status
    head :ok
  end

  def update_last_seen
    update_last_seen_on_conversation(DateTime.now.utc, assignee?)
  end

  def unread
    last_incoming_message = @conversation.messages.incoming.last
    last_seen_at = last_incoming_message.created_at - 1.second if last_incoming_message.present?
    update_last_seen_on_conversation(last_seen_at, true)
  end

  def custom_attributes
    @conversation.custom_attributes = params.permit(custom_attributes: {})[:custom_attributes]
    @conversation.save!
  end

  private

  # ✅ SERVICIO: Lógica principal de actualización kanban
  def update_conversation_kanban_fields(conversation, params)
    Rails.logger.info "🔧 SERVICE: update_conversation_kanban_fields iniciado"
    
    # Validar kanban_type_process si está presente
    if params[:kanban_type_process_id].present?
      kanban_type_process = validate_kanban_type_process(params[:kanban_type_process_id])
      return { success: false, errors: ['Unauthorized kanban type process'] } unless kanban_type_process
    end

    # Validar kanban_process si está presente
    if params[:kanban_process_id].present?
      kanban_process = validate_kanban_process(params[:kanban_process_id], params[:kanban_type_process_id])
      return { success: false, errors: ['Unauthorized kanban process'] } unless kanban_process
    end

    # Actualizar la conversación
    if conversation.update(params)
      Rails.logger.info "✅ SERVICE: Conversación actualizada con éxito"
      { success: true, conversation: conversation }
    else
      Rails.logger.error "❌ SERVICE: Error actualizando conversación: #{conversation.errors.full_messages}"
      { success: false, errors: conversation.errors.full_messages }
    end
  end

  # ✅ VALIDACIÓN: Verificar que kanban_type_process pertenece a la cuenta
  def validate_kanban_type_process(kanban_type_process_id)
    Rails.logger.info "🔍 VALIDATION: Validando kanban_type_process_id: #{kanban_type_process_id}"
    
    kanban_type_process = Current.account.kanban_type_processes.find_by(id: kanban_type_process_id)
    
    if kanban_type_process
      Rails.logger.info "✅ VALIDATION: kanban_type_process válido: #{kanban_type_process.process_name}"
    else
      Rails.logger.warn "⚠️ VALIDATION: kanban_type_process no encontrado o no autorizado"
    end
    
    kanban_type_process
  end

  # ✅ VALIDACIÓN: Verificar que kanban_process pertenece a la cuenta y al tipo
  def validate_kanban_process(kanban_process_id, kanban_type_process_id = nil)
    Rails.logger.info "🔍 VALIDATION: Validando kanban_process_id: #{kanban_process_id}"
    Rails.logger.info "🔍 VALIDATION: Para kanban_type_process_id: #{kanban_type_process_id}"
    
    # Query base: debe pertenecer a la cuenta
    query = Current.account.kanban_processes.where(id: kanban_process_id)
    
    # Si se especifica kanban_type_process_id, también validar esa relación
    if kanban_type_process_id.present?
      query = query.where(kanban_type_process_id: kanban_type_process_id)
    end
    
    kanban_process = query.first
    
    if kanban_process
      Rails.logger.info "✅ VALIDATION: kanban_process válido: #{kanban_process.type_process_name}"
    else
      Rails.logger.warn "⚠️ VALIDATION: kanban_process no encontrado o no autorizado"
    end
    
    kanban_process
  end

 # ✅ FORMATO: Respuesta estándar de conversación con datos kanban (versión simple)
def format_conversation_response(conversation)
  conversation.as_json(
    include: {
      kanban_type_process: {
        only: [:id, :process_name, :default, :is_system],
        include: {
          kanban_processes: {
            only: [:id, :type_process_name, :position, :default, :is_system]
          }
        }
      },
      kanban_process: {
        only: [:id, :type_process_name, :position, :default, :is_system]
      },
      messages: {
        include: {
          sender: {
            only: [:id, :name, :available_name, :avatar_url, :email, :thumbnail]
          },
          attachments: {
            only: [:id, :file_type, :file_url, :thumb_url, :data_url]
          }
        }
      },
      inbox: {
        only: [:id, :name, :channel_type]
      },
      contact: {
        only: [:id, :name, :email, :phone_number, :identifier, :thumbnail, :additional_attributes]
      },
      labels: {
        only: [:id, :title, :description, :color, :show_on_sidebar]
      }
    }
  )
end

  # ✅ ERRORS: Respuestas de error estándar
  def render_unauthorized_kanban_type_process
    render json: { 
      error: 'Kanban type process not found or not authorized for this account' 
    }, status: :unprocessable_entity
  end

  def render_unauthorized_kanban_process
    render json: { 
      error: 'Kanban process not found or not authorized for this account' 
    }, status: :unprocessable_entity
  end

  def conversation_params
    # Parámetros originales mantenidos
    params.require(:conversation).permit(
      :kanban_type_process_id,
      :kanban_process_id
    )
  end

  # ✅ PARAMS ORIGINALES: Mantenidos para compatibilidad
  def kanban_process_params
    params.require(:conversation).permit(:kanban_type_process_id, :kanban_process_id)
  end

  # ✅ PARAMS MEJORADOS: Para métodos nuevos
  def kanban_process_params_enhanced
    params.permit(:kanban_type_process_id, :kanban_process_id)
  end

  def permitted_update_params
    # TODO: Move the other conversation attributes to this method and remove specific endpoints for each attribute
    params.permit(:priority)
  end

  def update_last_seen_on_conversation(last_seen_at, update_assignee)
    # rubocop:disable Rails/SkipsModelValidations
    @conversation.update_column(:agent_last_seen_at, last_seen_at)
    @conversation.update_column(:assignee_last_seen_at, last_seen_at) if update_assignee.present?
    # rubocop:enable Rails/SkipsModelValidations
  end

  def set_conversation_status
    @conversation.status = params[:status]
    @conversation.snoozed_until = parse_date_time(params[:snoozed_until].to_s) if params[:snoozed_until]
  end

  def assign_conversation
    @conversation.assignee = current_user
    @conversation.save!
  end

  def conversation
    @conversation ||= Current.account.conversations.find_by!(display_id: params[:id])
    authorize @conversation.inbox, :show?
  end

  def inbox
    return if params[:inbox_id].blank?

    @inbox = Current.account.inboxes.find(params[:inbox_id])
    authorize @inbox, :show?
  end

  def contact
    return if params[:contact_id].blank?

    @contact = Current.account.contacts.find(params[:contact_id])
  end

  def contact_inbox
    @contact_inbox = build_contact_inbox

    # fallback for the old case where we do look up only using source id
    # In future we need to change this and make sure we do look up on combination of inbox_id and source_id
    # and deprecate the support of passing only source_id as the param
    @contact_inbox ||= ::ContactInbox.find_by!(source_id: params[:source_id])
    authorize @contact_inbox.inbox, :show?
  rescue ActiveRecord::RecordNotUnique
    render json: { error: 'source_id should be unique' }, status: :unprocessable_entity
  end

  def build_contact_inbox
    return if @inbox.blank? || @contact.blank?

    ContactInboxBuilder.new(
      contact: @contact,
      inbox: @inbox,
      source_id: params[:source_id],
      hmac_verified: hmac_verified?
    ).perform
  end

  def conversation_finder
    @conversation_finder ||= ConversationFinder.new(Current.user, params)
  end

  def assignee?
    @conversation.assignee_id? && Current.user == @conversation.assignee
  end
end

Api::V1::Accounts::ConversationsController.prepend_mod_with('Api::V1::Accounts::ConversationsController')