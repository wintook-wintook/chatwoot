# Proyecto: DEV0001
# app/controllers/api/v1/accounts/scheduled_messages_controller.rb

# class Api::V1::Accounts::ScheduledMessagesController < Api::V1::Accounts::BaseController
#     before_action :fetch_conversation, only: [:index, :create]
#     before_action :fetch_scheduled_message, only: [:show, :update, :destroy]
    
#     def index
#       @scheduled_messages = if @conversation
#                              Current.account.scheduled_messages.where(conversation_id: @conversation.id)
#                            else
#                              Current.account.scheduled_messages
#                            end
#       @scheduled_messages = @scheduled_messages.where(sent: false) if params[:pending].present?
      
#       render json: @scheduled_messages
#     end
    
#     def show
#       render json: @scheduled_message
#     end
    
#     def create
#       # Capturar el parámetro de timezone
#       timezone = params[:timezone] || Current.user.preferences&.dig(:timezone) || 'UTC'
      
#       Time.use_zone(timezone) do
#         # Crear los atributos para el mensaje programado
#         message_attributes = build_message_attributes
        
#         @scheduled_message = Current.account.scheduled_messages.new(message_attributes)
#         @scheduled_message.user = Current.user
        
#         # Asignar la conversación
#         if @conversation
#           @scheduled_message.conversation = @conversation
#         else
#           return render json: { error: 'Se requiere una conversación válida' }, status: :unprocessable_entity
#         end
        
#         if @scheduled_message.save
#           render json: serialize_scheduled_message(@scheduled_message), status: :created
#         else
#           render json: { errors: @scheduled_message.errors }, status: :unprocessable_entity
#         end
#       end
#     end
    
#     def update
#       timezone = params[:timezone] || Current.user.preferences&.dig(:timezone) || 'UTC'
      
#       Time.use_zone(timezone) do
#         message_attributes = build_message_attributes(update: true)
        
#         if @scheduled_message.update(message_attributes)
#           render json: serialize_scheduled_message(@scheduled_message)
#         else
#           render json: { errors: @scheduled_message.errors }, status: :unprocessable_entity
#         end
#       end
#     end
    
#     def destroy
#       @scheduled_message.destroy
#       head :no_content
#     end
    
#     private
    
#     def build_message_attributes(update: false)
#       attributes = {
#         content: params[:content],
#         message_type: params[:message_type] || 'outgoing',
#         additional_attributes: params[:additional_attributes]
#       }
      
#       # Solo actualizar scheduled_at si se proporciona
#       if params[:scheduled_at].present?
#         attributes[:scheduled_at] = Time.zone.parse(params[:scheduled_at])
#       end
      
#       # Manejar campos de plantilla si están presentes
#       if params[:template_name].present?
#         attributes.merge!(
#           template_name: params[:template_name],
#           template_language: params[:template_language],
#           template_category: params[:template_category], 
#           template_namespace: params[:template_namespace],
#           template_params: params[:template_params],
#           is_template: true
#         )
#       elsif !update
#         # Solo establecer is_template: false en creación, no en actualización
#         attributes[:is_template] = false
#       end
      
#       attributes.compact
#     end
    
#     def serialize_scheduled_message(scheduled_message)
#       {
#         id: scheduled_message.id,
#         content: scheduled_message.content,
#         scheduled_at: scheduled_message.scheduled_at,
#         sent: scheduled_message.sent,
#         sent_at: scheduled_message.sent_at,
#         message_type: scheduled_message.message_type,
#         recipient_type: scheduled_message.message_type == 'private' ? 'agent' : 'contact',
#         template_name: scheduled_message.template_name,
#         template_language: scheduled_message.template_language,
#         template_category: scheduled_message.template_category,
#         template_params: scheduled_message.template_params,
#         is_template: scheduled_message.is_template?,
#         user: {
#           id: scheduled_message.user.id,
#           name: scheduled_message.user.name,
#           email: scheduled_message.user.email
#         },
#         created_at: scheduled_message.created_at,
#         updated_at: scheduled_message.updated_at
#       }
#     end
    
#     def fetch_conversation
#       return unless params[:conversation_id].present?
      
#       conversation_identifier = params[:conversation_id]
      
#       @conversation = Current.account.conversations.find_by(display_id: conversation_identifier)
#       @conversation ||= Current.account.conversations.find_by(id: conversation_identifier)
      
#       unless @conversation
#         render json: { error: "Conversación no encontrada con identificador: #{conversation_identifier}" }, status: :not_found
#         return
#       end
#     end
    
#     def fetch_scheduled_message
#       @scheduled_message = Current.account.scheduled_messages.find(params[:id])
#     rescue ActiveRecord::RecordNotFound
#       render json: { error: "Mensaje programado no encontrado con ID: #{params[:id]}" }, status: :not_found
#     end
#   end



# 21/08/2025
# 📁 ARCHIVO 2: app/controllers/api/v1/accounts/scheduled_messages_controller.rb
class Api::V1::Accounts::ScheduledMessagesController < Api::V1::Accounts::BaseController
  before_action :fetch_conversation, only: [:index, :create]
  before_action :fetch_scheduled_message, only: [:show, :update, :destroy]
  
  def index
    @scheduled_messages = if @conversation
                           Current.account.scheduled_messages.where(conversation_id: @conversation.id)
                         else
                           Current.account.scheduled_messages
                         end
    @scheduled_messages = @scheduled_messages.where(sent: false) if params[:pending].present?
    
    render json: @scheduled_messages
  end
  
  def show
    render json: @scheduled_message
  end
  
  def create
    timezone = params[:timezone] || Current.user.preferences&.dig(:timezone) || 'UTC'
    
    Time.use_zone(timezone) do
      message_attributes = build_message_attributes
      
      @scheduled_message = Current.account.scheduled_messages.new(message_attributes)
      @scheduled_message.user = Current.user
      
      if @conversation
        @scheduled_message.conversation = @conversation
      else
        return render json: { error: 'Se requiere una conversación válida' }, status: :unprocessable_entity
      end
      
      # Validación específica para plantillas
      if is_template_message? && !valid_template_data?
        return render json: { 
          error: 'Datos de plantilla incompletos',
          details: get_template_validation_errors
        }, status: :unprocessable_entity
      end
      
      if @scheduled_message.save
        render json: serialize_scheduled_message(@scheduled_message), status: :created
      else
        render json: { errors: @scheduled_message.errors }, status: :unprocessable_entity
      end
    end
  end
  
  def update
    timezone = params[:timezone] || Current.user.preferences&.dig(:timezone) || 'UTC'
    
    Time.use_zone(timezone) do
      message_attributes = build_message_attributes(update: true)
      
      if @scheduled_message.update(message_attributes)
        render json: serialize_scheduled_message(@scheduled_message)
      else
        render json: { errors: @scheduled_message.errors }, status: :unprocessable_entity
      end
    end
  end
  
  def destroy
    @scheduled_message.destroy
    head :no_content
  end
  
  private
  
  def build_message_attributes(update: false)
    attributes = {
      content: params[:content],
      message_type: determine_message_type,
      additional_attributes: build_additional_attributes
    }
    
    # Solo actualizar scheduled_at si se proporciona
    if params[:scheduled_at].present?
      attributes[:scheduled_at] = Time.zone.parse(params[:scheduled_at])
    end
    
    # Manejar campos de plantilla si están presentes
    if is_template_message?
      Rails.logger.info "Procesando mensaje de plantilla con params: #{template_params_from_request.inspect}"
      
      attributes.merge!(
        template_name: params[:template_name],
        template_language: params[:template_language],
        template_category: params[:template_category], 
        template_namespace: params[:template_namespace],
        template_params: extract_processed_params,
        is_template: true
      )
    elsif !update
      attributes[:is_template] = false
    end
    
    attributes.compact
  end
  
  def determine_message_type
    # Si es plantilla, usar tipo template
    return 'template' if is_template_message?
    
    # Si es recordatorio para agente
    return 'private' if params[:recipient_type] == 'agent'
    
    # Por defecto, mensaje saliente
    params[:message_type] || 'outgoing'
  end
  
  def build_additional_attributes
    base_attributes = params[:additional_attributes] || {}
    
    # Agregar tipo de destinatario
    base_attributes[:recipient_type] = params[:recipient_type] || 'contact'
    
    # Si es plantilla, agregar metadatos específicos
    if is_template_message?
      base_attributes[:whatsapp_template] = template_params_from_request
      base_attributes[:scheduled_template] = true
    end
    
    base_attributes
  end
  
  def is_template_message?
    params[:template_name].present? || params[:is_template] == true
  end
  
  def template_params_from_request
    return {} unless is_template_message?
    
    # Manejar tanto la estructura del frontend como parámetros directos
    if params[:template_params].present?
      # Viene del frontend con estructura completa
      template_data = params[:template_params]
      {
        name: template_data[:name] || params[:template_name],
        language: template_data[:language] || params[:template_language],
        category: template_data[:category] || params[:template_category],
        namespace: template_data[:namespace] || params[:template_namespace],
        processed_params: template_data[:processed_params] || {}
      }
    else
      # Parámetros directos
      {
        name: params[:template_name],
        language: params[:template_language],
        category: params[:template_category],
        namespace: params[:template_namespace],
        processed_params: params[:processed_params] || {}
      }
    end
  end
  
  def extract_processed_params
    template_data = template_params_from_request
    template_data[:processed_params] || {}
  end
  
  def valid_template_data?
    template_data = template_params_from_request
    template_data[:name].present? && 
    template_data[:language].present? && 
    template_data[:category].present?
  end
  
  def get_template_validation_errors
    template_data = template_params_from_request
    errors = []
    
    errors << 'template_name es requerido' unless template_data[:name].present?
    errors << 'template_language es requerido' unless template_data[:language].present?
    errors << 'template_category es requerido' unless template_data[:category].present?
    
    errors
  end
  
  def serialize_scheduled_message(scheduled_message)
    {
      id: scheduled_message.id,
      content: scheduled_message.content,
      scheduled_at: scheduled_message.scheduled_at,
      sent: scheduled_message.sent,
      sent_at: scheduled_message.sent_at,
      message_type: scheduled_message.message_type,
      recipient_type: scheduled_message.additional_attributes&.dig('recipient_type') || 
                     (scheduled_message.message_type == 'private' ? 'agent' : 'contact'),
      template_name: scheduled_message.template_name,
      template_language: scheduled_message.template_language,
      template_category: scheduled_message.template_category,
      template_params: scheduled_message.template_params,
      is_template: scheduled_message.is_template?,
      user: {
        id: scheduled_message.user.id,
        name: scheduled_message.user.name,
        email: scheduled_message.user.email
      },
      created_at: scheduled_message.created_at,
      updated_at: scheduled_message.updated_at
    }
  end
  
  def fetch_conversation
    return unless params[:conversation_id].present?
    
    conversation_identifier = params[:conversation_id]
    
    @conversation = Current.account.conversations.find_by(display_id: conversation_identifier)
    @conversation ||= Current.account.conversations.find_by(id: conversation_identifier)
    
    unless @conversation
      render json: { error: "Conversación no encontrada con identificador: #{conversation_identifier}" }, status: :not_found
      return
    end
  end
  
  def fetch_scheduled_message
    @scheduled_message = Current.account.scheduled_messages.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Mensaje programado no encontrado con ID: #{params[:id]}" }, status: :not_found
  end
end