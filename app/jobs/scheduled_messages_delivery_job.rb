# Proyecto: DEV0001
# class ScheduledMessagesDeliveryJob < ApplicationJob
#     queue_as :scheduled_messages
    
#     def perform
#       ScheduledMessage.pending.find_each do |scheduled_message|
#         begin
#           scheduled_message.deliver!
#         rescue => e
#           Rails.logger.error "Error al entregar el mensaje programado ID #{scheduled_message.id}: #{e.message}"
#         end
#       end
#     end
#   end

  # app/jobs/scheduled_messages_delivery_job.rb
# class ScheduledMessagesDeliveryJob < ApplicationJob
#   queue_as :scheduled_messages
  
#   def perform
#     Rails.logger.info "Ejecutando ScheduledMessagesDeliveryJob"
    
#     pending_messages = ScheduledMessage.pending
#     Rails.logger.info "Encontrados #{pending_messages.count} mensajes pendientes"
    
#     pending_messages.find_each do |scheduled_message|
#       begin
#         Rails.logger.info "Procesando mensaje programado ID: #{scheduled_message.id}"
#         scheduled_message.deliver!
#       rescue => e
#         Rails.logger.error "Error al entregar el mensaje programado ID #{scheduled_message.id}: #{e.message}"
#         Rails.logger.error e.backtrace.join("\n") if e.backtrace
#       end
#     end
    
#     Rails.logger.info "ScheduledMessagesDeliveryJob completado"
#   end
# end

# app/jobs/scheduled_messages_delivery_job.rb
# class ScheduledMessagesDeliveryJob < ApplicationJob
#   queue_as :low  # Usamos la misma cola que otros jobs similares en Chatwoot

#   def perform
#     # Similar al enfoque utilizado en ReopenSnoozedConversationsJob
#     ScheduledMessage.where(sent: false)
#                    .where(scheduled_at: 3.days.ago..Time.current)
#                    .find_each(batch_size: 100) do |scheduled_message|
#       begin
#         Rails.logger.info "Procesando mensaje programado ID: #{scheduled_message.id}"
#         scheduled_message.deliver!
#       rescue => e
#         Rails.logger.error "Error al entregar el mensaje programado ID #{scheduled_message.id}: #{e.message}"
#       end
#     end
#   end
# end

# 21/08/2025
# 📁 ARCHIVO 3: app/jobs/scheduled_messages_delivery_job.rb
class ScheduledMessagesDeliveryJob < ApplicationJob
  queue_as :low

  def perform
    Rails.logger.info "Iniciando ScheduledMessagesDeliveryJob"
    
    # Obtener mensajes pendientes con validación adicional
    pending_messages = ScheduledMessage.where(sent: false)
                                     .where(scheduled_at: 3.days.ago..Time.current)
                                     .includes(:conversation, :user, :account)
    
    Rails.logger.info "Encontrados #{pending_messages.count} mensajes pendientes"
    
    success_count = 0
    error_count = 0
    
    pending_messages.find_each(batch_size: 100) do |scheduled_message|
      begin
        Rails.logger.info "Procesando mensaje programado ID: #{scheduled_message.id} (Tipo: #{scheduled_message.is_template? ? 'Template' : 'Regular'})"
        
        # Validaciones adicionales antes del envío
        unless valid_for_delivery?(scheduled_message)
          Rails.logger.warn "Mensaje programado ID #{scheduled_message.id} no es válido para entrega"
          next
        end
        
        result = scheduled_message.deliver!
        
        if result
          success_count += 1
          Rails.logger.info "✅ Mensaje programado ID #{scheduled_message.id} entregado exitosamente"
        else
          error_count += 1
          Rails.logger.error "❌ Falló la entrega del mensaje programado ID #{scheduled_message.id}"
        end
        
      rescue => e
        error_count += 1
        Rails.logger.error "❌ Error al procesar mensaje programado ID #{scheduled_message.id}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n") if e.backtrace
      end
    end
    
    Rails.logger.info "ScheduledMessagesDeliveryJob completado. Éxitos: #{success_count}, Errores: #{error_count}"
  end
  
  private
  
  def valid_for_delivery?(scheduled_message)
    # Verificar que la conversación existe y está activa
    unless scheduled_message.conversation&.present?
      Rails.logger.error "Conversación no encontrada para mensaje programado ID #{scheduled_message.id}"
      return false
    end
    
    # Verificar que el usuario existe
    unless scheduled_message.user&.present?
      Rails.logger.error "Usuario no encontrado para mensaje programado ID #{scheduled_message.id}"
      return false
    end
    
    # Verificar que la cuenta existe
    unless scheduled_message.account&.present?
      Rails.logger.error "Cuenta no encontrada para mensaje programado ID #{scheduled_message.id}"
      return false
    end
    
    # Verificación específica para plantillas
    if scheduled_message.is_template?
      unless scheduled_message.template_name.present? && 
             scheduled_message.template_language.present? &&
             scheduled_message.template_category.present?
        Rails.logger.error "Plantilla incompleta para mensaje programado ID #{scheduled_message.id}"
        return false
      end
      
      # Verificar que el inbox soporta plantillas (WhatsApp)
      inbox = scheduled_message.conversation.inbox
      unless supports_templates?(inbox)
        Rails.logger.error "El inbox ID #{inbox&.id} no soporta plantillas para mensaje programado ID #{scheduled_message.id}"
        return false
      end
    end
    
    true
  end
  
  def supports_templates?(inbox)
    return false unless inbox
    
    # Verificar si es un canal WhatsApp Business
    inbox.channel_type == 'Channel::Whatsapp' || 
    inbox.additional_attributes&.dig('provider_config', 'api_key').present?
  end
end
