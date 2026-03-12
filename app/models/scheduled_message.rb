# == Schema Information
#
# Table name: scheduled_messages
#
#  id                    :bigint           not null, primary key
#  additional_attributes :json
#  content               :text             not null
#  is_template           :boolean          default(FALSE)
#  message_type          :string           default("outgoing")
#  scheduled_at          :datetime         not null
#  sent                  :boolean          default(FALSE)
#  sent_at               :datetime
#  template_category     :string
#  template_language     :string
#  template_name         :string
#  template_namespace    :string
#  template_params       :json
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :bigint           not null
#  conversation_id       :bigint           not null
#  user_id               :bigint           not null
#
# Indexes
#
#  index_scheduled_messages_on_account_id       (account_id)
#  index_scheduled_messages_on_conversation_id  (conversation_id)
#  index_scheduled_messages_on_user_id          (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (user_id => users.id)
#

# class ScheduledMessage < ApplicationRecord
#     belongs_to :account
#     belongs_to :conversation
#     belongs_to :user
    
#     validates :content, presence: true
#     validates :scheduled_at, presence: true
    
#     scope :pending, -> { where(sent: false).where('scheduled_at <= ?', Time.current) }
#     scope :templates, -> { where(is_template: true) }
#     scope :regular_messages, -> { where(is_template: false) }
    
#     def deliver!
#       Rails.logger.info "Intentando entregar mensaje programado ID: #{id}"
      
#       return if sent?
      
#       # Verificar que la conversación existe
#       unless conversation.present?
#         Rails.logger.error "Error al entregar mensaje programado ID #{id}: La conversación no existe"
#         return
#       end
      
#       # Obtener el inbox de la conversación
#       inbox_id = conversation.inbox_id
      
#       begin
#         # Preparar los atributos adicionales
#         safe_additional_attributes = additional_attributes.is_a?(Hash) ? additional_attributes : {}
        
#         if is_agent_reminder?
#           # Crear recordatorio privado para agentes
#           message = create_agent_reminder(inbox_id, safe_additional_attributes)
#         elsif is_template? && template_name.present?
#           # Crear mensaje de plantilla WhatsApp
#           message = create_template_message(inbox_id, safe_additional_attributes)
#         else
#           # Crear mensaje normal al contacto
#           message = create_regular_message(inbox_id, safe_additional_attributes)
#         end
        
#         update!(
#           sent: true,
#           sent_at: Time.current
#         )
        
#         Rails.logger.info "Mensaje programado ID #{id} entregado exitosamente como mensaje ID #{message.id}"
        
#         message
#       rescue => e
#         Rails.logger.error "Error al entregar mensaje programado ID #{id}: #{e.message}"
#         Rails.logger.error e.backtrace.join("\n") if e.backtrace
#         # No volver a lanzar la excepción para que otros mensajes puedan procesarse
#       end
#     end
    
#     def is_agent_reminder?
#       message_type == 'private' || additional_attributes&.dig('recipient_type') == 'agent'
#     end
    
#     private
    
#     def create_agent_reminder(inbox_id, safe_additional_attributes)
#       # Los recordatorios para agentes son mensajes internos/privados
#       conversation.messages.create!(
#         account_id: account_id,
#         inbox_id: inbox_id,
#         message_type: 'outgoing',
#         content: "🔔 **RECORDATORIO**: #{content}",
#         sender: user,
#         additional_attributes: safe_additional_attributes.merge(
#           scheduled_reminder: true,
#           recipient_type: 'agent'
#         ),
#         content_type: 'text',
#         content_attributes: {},
#         private: true  # Este campo marca el mensaje como privado
#       )
#     end
    
#     def create_template_message(inbox_id, safe_additional_attributes)
#       # Preparar los parámetros de la plantilla
#       template_params_hash = {
#         name: template_name,
#         language: template_language,
#         category: template_category,
#         namespace: template_namespace,
#         processed_params: template_params || {}
#       }
      
#       # Crear mensaje con tipo 'template' específico para plantillas WhatsApp
#       conversation.messages.create!(
#         account_id: account_id,
#         inbox_id: inbox_id,
#         message_type: 'template',  # Usar el tipo 'template' específico
#         content: content, # El contenido procesado para visualización
#         sender: user,
#         additional_attributes: safe_additional_attributes.merge(
#           scheduled_template: true,
#           recipient_type: 'contact'
#         ),
#         content_type: 'text',
#         content_attributes: {
#           # Marcar como mensaje de plantilla con parámetros
#           template_params: template_params_hash
#         }
#       )
#     end
    
#     def create_regular_message(inbox_id, safe_additional_attributes)
#       conversation.messages.create!(
#         account_id: account_id,
#         inbox_id: inbox_id,
#         message_type: 'outgoing',
#         content: content,
#         sender: user,
#         additional_attributes: safe_additional_attributes.merge(
#           scheduled_message: true,
#           recipient_type: 'contact'
#         ),
#         content_type: 'text',
#         content_attributes: {}
#       )
#     end
#   end

# 21 Agosto 2025 
# 📁 ARCHIVO 1: app/models/scheduled_message.rb
# class ScheduledMessage < ApplicationRecord
#   belongs_to :account
#   belongs_to :conversation
#   belongs_to :user
  
#   validates :content, presence: true
#   validates :scheduled_at, presence: true
  
#   # Validaciones específicas para plantillas
#   validates :template_name, presence: true, if: :is_template?
#   validates :template_language, presence: true, if: :is_template?
#   validates :template_category, presence: true, if: :is_template?
  
#   scope :pending, -> { where(sent: false).where('scheduled_at <= ?', Time.current) }
#   scope :templates, -> { where(is_template: true) }
#   scope :regular_messages, -> { where(is_template: false) }
  
#   def deliver!
#     Rails.logger.info "Intentando entregar mensaje programado ID: #{id}"
    
#     return if sent?
    
#     unless conversation.present?
#       Rails.logger.error "Error al entregar mensaje programado ID #{id}: La conversación no existe"
#       return
#     end
    
#     # Validar plantilla antes del envío
#     if is_template? && !valid_template?
#       Rails.logger.error "Error al entregar mensaje programado ID #{id}: Plantilla inválida"
#       return
#     end
    
#     inbox_id = conversation.inbox_id
    
#     begin
#       safe_additional_attributes = additional_attributes.is_a?(Hash) ? additional_attributes : {}
      
#       if is_agent_reminder?
#         message = create_agent_reminder(inbox_id, safe_additional_attributes)
#       elsif is_template? && template_name.present?
#         message = create_template_message(inbox_id, safe_additional_attributes)
#       else
#         message = create_regular_message(inbox_id, safe_additional_attributes)
#       end
      
#       update!(
#         sent: true,
#         sent_at: Time.current
#       )
      
#       Rails.logger.info "Mensaje programado ID #{id} entregado exitosamente como mensaje ID #{message.id}"
#       message
#     rescue => e
#       Rails.logger.error "Error al entregar mensaje programado ID #{id}: #{e.message}"
#       Rails.logger.error e.backtrace.join("\n") if e.backtrace
#       nil
#     end
#   end
  
#   def is_agent_reminder?
#     message_type == 'private' || additional_attributes&.dig('recipient_type') == 'agent'
#   end
  
#   def valid_template?
#     return true unless is_template?
    
#     template_name.present? && 
#     template_language.present? && 
#     template_category.present?
#   end
  
#   private
  
#   def create_agent_reminder(inbox_id, safe_additional_attributes)
#     conversation.messages.create!(
#       account_id: account_id,
#       inbox_id: inbox_id,
#       message_type: 'outgoing',
#       content: "📅 **RECORDATORIO**: #{content}",
#       sender: user,
#       additional_attributes: safe_additional_attributes.merge(
#         scheduled_reminder: true,
#         recipient_type: 'agent'
#       ),
#       content_type: 'text',
#       content_attributes: {},
#       private: true
#     )
#   end
  
#   # def create_template_message(inbox_id, safe_additional_attributes)
#   #   # Estructura específica para plantillas WhatsApp de Chatwoot
#   #   template_data = {
#   #     name: template_name,
#   #     language: template_language,
#   #     category: template_category,
#   #     namespace: template_namespace,
#   #     processed_params: template_params || {}
#   #   }
    
#   #   Rails.logger.info "Enviando plantilla WhatsApp: #{template_data.inspect}"
    
#   #   # Crear mensaje con estructura que Chatwoot reconoce para WhatsApp templates
#   #   conversation.messages.create!(
#   #     account_id: account_id,
#   #     inbox_id: inbox_id,
#   #     message_type: 'template', # Importante: debe ser 'template'
#   #     content: content,
#   #     sender: user,
#   #     additional_attributes: safe_additional_attributes.merge(
#   #       scheduled_template: true,
#   #       recipient_type: 'contact',
#   #       # Estructura específica para WhatsApp Business API
#   #       whatsapp_template: template_data
#   #     ),
#   #     content_type: 'template', # También importante
#   #     content_attributes: {
#   #       template_params: template_data,
#   #       # Agregar metadatos específicos para el canal WhatsApp
#   #       message_template: {
#   #         name: template_name,
#   #         language: template_language,
#   #         category: template_category,
#   #         namespace: template_namespace,
#   #         components: build_template_components
#   #       }
#   #     }
#   #   )
#   # end
  
#   # 🔧 CORRECIÓN URGENTE para scheduled_message.rb
#   # REEMPLAZAR el método create_template_message en tu modelo

#   def create_template_message(inbox_id, safe_additional_attributes)
#     # Verificar qué content_types están permitidos en Chatwoot
#     # Generalmente son: 'text', 'input_text', 'cards', 'form', 'article'
    
#     # Estructura específica para plantillas WhatsApp de Chatwoot
#     template_data = {
#       name: template_name,
#       language: template_language,
#       category: template_category,
#       namespace: template_namespace,
#       processed_params: template_params || {}
#     }
    
#     Rails.logger.info "Enviando plantilla WhatsApp: #{template_data.inspect}"
    
#     # USAR 'text' como content_type (valor válido) pero message_type 'template'
#     conversation.messages.create!(
#       account_id: account_id,
#       inbox_id: inbox_id,
#       message_type: 'template',  # Este sí puede ser 'template'
#       content: content,
#       sender: user,
#       additional_attributes: safe_additional_attributes.merge(
#         scheduled_template: true,
#         recipient_type: 'contact',
#         # Estructura específica para WhatsApp Business API
#         whatsapp_template: template_data
#       ),
#       content_type: 'text',  # 🔧 CAMBIO: usar 'text' en lugar de 'template'
#       content_attributes: {
#         template_params: template_data,
#         # Agregar metadatos específicos para el canal WhatsApp
#         message_template: {
#           name: template_name,
#           language: template_language,
#           category: template_category,
#           namespace: template_namespace,
#           components: build_template_components
#         }
#       }
#     )
#   end

#   def create_regular_message(inbox_id, safe_additional_attributes)
#     conversation.messages.create!(
#       account_id: account_id,
#       inbox_id: inbox_id,
#       message_type: 'outgoing',
#       content: content,
#       sender: user,
#       additional_attributes: safe_additional_attributes.merge(
#         scheduled_message: true,
#         recipient_type: 'contact'
#       ),
#       content_type: 'text',
#       content_attributes: {}
#     )
#   end
  
#   def build_template_components
#     # Construir los componentes de la plantilla según el formato de WhatsApp Business API
#     components = []
    
#     if template_params.present? && template_params.is_a?(Hash)
#       # Componente BODY con parámetros
#       body_params = template_params.map do |key, value|
#         { type: 'text', text: value.to_s }
#       end
      
#       components << {
#         type: 'BODY',
#         parameters: body_params
#       }
#     end
    
#     components
#   end
# end


# 📁 ARCHIVO 1: app/models/scheduled_message.rb
# class ScheduledMessage < ApplicationRecord
#   belongs_to :account
#   belongs_to :conversation
#   belongs_to :user
  
#   validates :content, presence: true
#   validates :scheduled_at, presence: true
  
#   # Validaciones específicas para plantillas
#   validates :template_name, presence: true, if: :is_template?
#   validates :template_language, presence: true, if: :is_template?
#   validates :template_category, presence: true, if: :is_template?
  
#   scope :pending, -> { where(sent: false).where('scheduled_at <= ?', Time.current) }
#   scope :templates, -> { where(is_template: true) }
#   scope :regular_messages, -> { where(is_template: false) }
  
#   def deliver!
#     Rails.logger.info "Intentando entregar mensaje programado ID: #{id}"
    
#     return if sent?
    
#     unless conversation.present?
#       Rails.logger.error "Error al entregar mensaje programado ID #{id}: La conversación no existe"
#       return
#     end
    
#     # Validar plantilla antes del envío
#     if is_template? && !valid_template?
#       Rails.logger.error "Error al entregar mensaje programado ID #{id}: Plantilla inválida"
#       return
#     end
    
#     inbox_id = conversation.inbox_id
    
#     begin
#       safe_additional_attributes = additional_attributes.is_a?(Hash) ? additional_attributes : {}
      
#       if is_agent_reminder?
#         message = create_agent_reminder(inbox_id, safe_additional_attributes)
#       elsif is_template? && template_name.present?
#         message = create_template_message(inbox_id, safe_additional_attributes)
#       else
#         message = create_regular_message(inbox_id, safe_additional_attributes)
#       end
      
#       update!(
#         sent: true,
#         sent_at: Time.current
#       )
      
#       Rails.logger.info "Mensaje programado ID #{id} entregado exitosamente como mensaje ID #{message.id}"
#       message
#     rescue => e
#       Rails.logger.error "Error al entregar mensaje programado ID #{id}: #{e.message}"
#       Rails.logger.error e.backtrace.join("\n") if e.backtrace
#       nil
#     end
#   end
  
#   def is_agent_reminder?
#     message_type == 'private' || additional_attributes&.dig('recipient_type') == 'agent'
#   end
  
#   def valid_template?
#     return true unless is_template?
    
#     template_name.present? && 
#     template_language.present? && 
#     template_category.present?
#   end
  
#   private
  
#   def create_agent_reminder(inbox_id, safe_additional_attributes)
#     conversation.messages.create!(
#       account_id: account_id,
#       inbox_id: inbox_id,
#       message_type: 'outgoing',
#       content: "📅 **RECORDATORIO**: #{content}",
#       sender: user,
#       additional_attributes: safe_additional_attributes.merge(
#         scheduled_reminder: true,
#         recipient_type: 'agent'
#       ),
#       content_type: 'text',
#       content_attributes: {},
#       private: true
#     )
#   end
  
#   def create_template_message(inbox_id, safe_additional_attributes)
#     # Estructura específica para plantillas WhatsApp de Chatwoot
#     template_data = {
#       name: template_name,
#       language: template_language,
#       category: template_category,
#       namespace: template_namespace,
#       processed_params: template_params || {}
#     }
    
#     Rails.logger.info "Enviando plantilla WhatsApp: #{template_data.inspect}"
    
#     # Crear mensaje con estructura que Chatwoot reconoce para WhatsApp templates
#     conversation.messages.create!(
#       account_id: account_id,
#       inbox_id: inbox_id,
#       message_type: 'template', # Importante: debe ser 'template'
#       content: content,
#       sender: user,
#       additional_attributes: safe_additional_attributes.merge(
#         scheduled_template: true,
#         recipient_type: 'contact',
#         # Estructura específica para WhatsApp Business API
#         whatsapp_template: template_data
#       ),
#       content_type: 'text', # 🔧 FIX: 'template' no es válido, usar 'text'
#       content_attributes: {
#         template_params: template_data,
#         # Agregar metadatos específicos para el canal WhatsApp
#         message_template: {
#           name: template_name,
#           language: template_language,
#           category: template_category,
#           namespace: template_namespace,
#           components: build_template_components
#         }
#       }
#     )
#   end
  
#   def create_regular_message(inbox_id, safe_additional_attributes)
#     conversation.messages.create!(
#       account_id: account_id,
#       inbox_id: inbox_id,
#       message_type: 'outgoing',
#       content: content,
#       sender: user,
#       additional_attributes: safe_additional_attributes.merge(
#         scheduled_message: true,
#         recipient_type: 'contact'
#       ),
#       content_type: 'text',
#       content_attributes: {}
#     )
#   end
  
#   def build_template_components
#     # Construir los componentes de la plantilla según el formato de WhatsApp Business API
#     components = []
    
#     if template_params.present? && template_params.is_a?(Hash)
#       # Componente BODY con parámetros
#       body_params = template_params.map do |key, value|
#         { type: 'text', text: value.to_s }
#       end
      
#       components << {
#         type: 'BODY',
#         parameters: body_params
#       }
#     end
    
#     components
#   end
# end


# 📁 ARCHIVO 1: app/models/scheduled_message.rb
class ScheduledMessage < ApplicationRecord
  belongs_to :account
  belongs_to :conversation
  belongs_to :user
  
  validates :content, presence: true
  validates :scheduled_at, presence: true
  
  # Validaciones específicas para plantillas
  validates :template_name, presence: true, if: :is_template?
  validates :template_language, presence: true, if: :is_template?
  validates :template_category, presence: true, if: :is_template?
  
  scope :pending, -> { where(sent: false).where('scheduled_at <= ?', Time.current) }
  scope :templates, -> { where(is_template: true) }
  scope :regular_messages, -> { where(is_template: false) }
  
  def deliver!
    Rails.logger.info "Intentando entregar mensaje programado ID: #{id}"
    
    return if sent?
    
    unless conversation.present?
      Rails.logger.error "Error al entregar mensaje programado ID #{id}: La conversación no existe"
      return
    end
    
    # Validar plantilla antes del envío
    if is_template? && !valid_template?
      Rails.logger.error "Error al entregar mensaje programado ID #{id}: Plantilla inválida"
      return
    end
    
    inbox_id = conversation.inbox_id
    
    begin
      safe_additional_attributes = additional_attributes.is_a?(Hash) ? additional_attributes : {}
      
      if is_agent_reminder?
        message = create_agent_reminder(inbox_id, safe_additional_attributes)
      elsif is_template? && template_name.present?
        message = create_template_message(inbox_id, safe_additional_attributes)
      else
        message = create_regular_message(inbox_id, safe_additional_attributes)
      end
      
      update!(
        sent: true,
        sent_at: Time.current
      )
      
      Rails.logger.info "Mensaje programado ID #{id} entregado exitosamente como mensaje ID #{message.id}"
      message
    rescue => e
      Rails.logger.error "Error al entregar mensaje programado ID #{id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if e.backtrace
      nil
    end
  end
  
  def is_agent_reminder?
    message_type == 'private' || additional_attributes&.dig('recipient_type') == 'agent'
  end
  
  def valid_template?
    return true unless is_template?
    
    template_name.present? && 
    template_language.present? && 
    template_category.present?
  end
  
  private
  
  def create_agent_reminder(inbox_id, safe_additional_attributes)
    conversation.messages.create!(
      account_id: account_id,
      inbox_id: inbox_id,
      message_type: 'outgoing',
      content: "📅 **RECORDATORIO**: #{content}",
      sender: user,
      additional_attributes: safe_additional_attributes.merge(
        scheduled_reminder: true,
        recipient_type: 'agent'
      ),
      content_type: 'text',
      content_attributes: {},
      private: true
    )
  end
  
  def create_template_message(inbox_id, safe_additional_attributes)
    Rails.logger.info "🎯 Usando estructura NATIVA de Chatwoot para plantillas"
    
    # Estructura EXACTA como el log exitoso de Chatwoot
    template_data = {
      "name" => template_name,
      "category" => template_category,
      "language" => template_language,
      "processed_params" => template_params || {}
    }
    
    Rails.logger.info "📋 Template data: #{template_data.inspect}"
    
    begin
      message = conversation.messages.create!(
        account_id: account_id,
        inbox_id: inbox_id,
        
        # 🎯 USAR VALOR NUMÉRICO como el sistema nativo
        message_type: Message.message_types['outgoing'] || 1,
        
        content: content,
        sender: user,
        
        # 🎯 ESTRUCTURA EXACTA del log exitoso
        additional_attributes: safe_additional_attributes.merge(
          "template_params" => template_data,  # Clave en string como nativo
          scheduled_template: true,
          recipient_type: 'contact'
        ),
        
        # 🎯 content_type 'text' como en log exitoso
        content_type: 'text',
        
        # 🎯 content_attributes VACÍO como en log exitoso
        content_attributes: {}
      )
      
      Rails.logger.info "✅ Mensaje creado con estructura NATIVA ID: #{message.id}"
      message
      
    rescue => e
      Rails.logger.error "❌ Error con estructura nativa: #{e.message}"
      raise e
    end
  end
  
  def create_regular_message(inbox_id, safe_additional_attributes)
    conversation.messages.create!(
      account_id: account_id,
      inbox_id: inbox_id,
      message_type: 'outgoing',
      content: content,
      sender: user,
      additional_attributes: safe_additional_attributes.merge(
        scheduled_message: true,
        recipient_type: 'contact'
      ),
      content_type: 'text',
      content_attributes: {}
    )
  end
  
  def build_template_components
    # Construir los componentes de la plantilla según el formato de WhatsApp Business API
    components = []
    
    if template_params.present? && template_params.is_a?(Hash)
      # Componente BODY con parámetros
      body_params = template_params.map do |key, value|
        { type: 'text', text: value.to_s }
      end
      
      components << {
        type: 'BODY',
        parameters: body_params
      }
    end
    
    components
  end
end
