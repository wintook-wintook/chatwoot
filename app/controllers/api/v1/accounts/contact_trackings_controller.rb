# frozen_string_literal: true
# /home/chatwoot/chatwoot/app/controllers/api/v1/accounts/contact_trackings_controller.rb
# ================================================================================
# proyecto@contact_tracking
# ================================================================================
# Controller: ContactTrackingsController
# Descripción: API REST para gestión completa de seguimientos de contactos
#              Provee endpoints CRUD y acciones de control (pause, resume, cancel)
# Funcionalidades:
#   - GET /contact_trackings - Listar con filtros avanzados
#   - POST /contact_trackings - Crear nuevo seguimiento
#   - GET /contact_trackings/:id - Ver detalle
#   - PATCH /contact_trackings/:id - Editar seguimiento
#   - DELETE /contact_trackings/:id - Eliminar seguimiento
#   - POST /contact_trackings/:id/pause - Pausar ejecución
#   - POST /contact_trackings/:id/resume - Reanudar ejecución
#   - POST /contact_trackings/:id/cancel - Cancelar seguimiento
# Seguridad:
#   - Autenticación mediante tokens de Chatwoot
#   - Autorización por inbox asignado al usuario
#   - Validación de ownership por account_id
# Autor: Chatwoot Follow-up AI Bot
# Versión: 2.0.0 (con WhatsApp Templates)
# ================================================================================

class Api::V1::Accounts::ContactTrackingsController < Api::V1::Accounts::BaseController
  # ==============================================================================
  # Before Actions
  # ==============================================================================
  before_action :set_contact, except: %i[improve_text]
  before_action :set_tracking, only: %i[show update destroy pause resume cancel]
  before_action :authorize_inbox_access, only: %i[create update]

  # ==============================================================================
  # GET /api/v1/accounts/:account_id/contacts/:contact_id/contact_trackings
  # ==============================================================================
  # Descripción: Lista todos los seguimientos de un contacto con filtros opcionales
  # Parámetros:
  #   - conversation_id: Filtrar por conversación específica
  #   - inbox_id: Filtrar por inbox
  #   - status: Filtrar por estado (pending, active, completed, etc.)
  #   - date_from: Fecha inicio (scheduled_for >= date_from)
  #   - date_to: Fecha fin (scheduled_for <= date_to)
  #   - search: Búsqueda en objective y last_message_sent
  #   - page: Número de página para paginación
  # ==============================================================================
  def index
    @trackings = @contact.contact_trackings
                         .where(account_id: Current.account.id)

    # Aplicar filtros (convertir display_id a id real si es necesario)
    if params[:conversation_id].present?
      real_conversation_id = resolve_conversation_id(params[:conversation_id])
      @trackings = @trackings.where(conversation_id: real_conversation_id) if real_conversation_id
    end
    @trackings = @trackings.where(inbox_id: params[:inbox_id]) if params[:inbox_id].present?
    @trackings = @trackings.where(status: params[:status]) if params[:status].present?
    
    # Filtros de rango de fechas
    @trackings = @trackings.where('scheduled_for >= ?', params[:date_from]) if params[:date_from].present?
    @trackings = @trackings.where('scheduled_for <= ?', params[:date_to]) if params[:date_to].present?
    
    # Búsqueda de texto
    if params[:search].present?
      search_term = "%#{params[:search].downcase}%"
      @trackings = @trackings.where(
        'LOWER(objective) LIKE ? OR LOWER(last_message_sent) LIKE ?',
        search_term, search_term
      )
    end

    @trackings = @trackings.order(created_at: :desc).page(params[:page])

    render json: {
      trackings: @trackings.map { |t| tracking_json(t) },
      meta: pagination_meta(@trackings)
    }
  end

  # ==============================================================================
  # GET /api/v1/accounts/:account_id/contacts/:contact_id/contact_trackings/:id
  # ==============================================================================
  # Descripción: Obtiene el detalle completo de un seguimiento específico
  # ==============================================================================
  def show
    render json: { tracking: tracking_json(@tracking) }
  end

  # ==============================================================================
  # POST /api/v1/accounts/:account_id/contacts/:contact_id/contact_trackings
  # ==============================================================================
  # Descripción: Crea un nuevo seguimiento para el contacto
  # Parámetros requeridos:
  #   - objective: Objetivo del seguimiento
  #   - scheduled_for: Fecha/hora de ejecución (ISO 8601)
  #   - inbox_id: ID del inbox
  # Parámetros opcionales:
  #   - max_attempts: Número máximo de intentos (default: 3)
  #   - retry_interval_value: Valor del intervalo (default: 30)
  #   - retry_interval_unit: Unidad del intervalo (default: "minutes")
  #   - whatsapp_templates: Array de nombres de plantillas por intento
  #   - conversation_id: ID de conversación relacionada
  #   - ai_context: Contexto para generación de mensajes con IA
  #   - quote_id: ID de cotización relacionada
  # ==============================================================================
  def create
    @tracking = @contact.contact_trackings.new(tracking_params)
    @tracking.account = Current.account
    @tracking.status = 'pending'

    # ⭐ El frontend envía display_id como conversation_id, convertir a ID real
    if @tracking.conversation_id.present?
      @tracking.conversation_id = resolve_conversation_id(@tracking.conversation_id)
    end

    if @tracking.save
      render json: { tracking: tracking_json(@tracking) }, status: :created
    else
      render json: {
        errors: @tracking.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # ==============================================================================
  # PATCH/PUT /api/v1/accounts/:account_id/contacts/:contact_id/contact_trackings/:id
  # ==============================================================================
  # Descripción: Actualiza un seguimiento existente
  # Nota: No se puede cambiar el contact_id ni account_id
  # ==============================================================================
  def update
    update_params = tracking_params.to_h

    # ⭐ Convertir display_id a id real si se está actualizando conversation_id
    if update_params[:conversation_id].present?
      update_params[:conversation_id] = resolve_conversation_id(update_params[:conversation_id])
    end

    if @tracking.update(update_params)
      render json: { tracking: tracking_json(@tracking) }
    else
      render json: {
        errors: @tracking.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # ==============================================================================
  # DELETE /api/v1/accounts/:account_id/contacts/:contact_id/contact_trackings/:id
  # ==============================================================================
  # Descripción: Elimina permanentemente un seguimiento
  # ==============================================================================
  def destroy
    @tracking.destroy
    head :no_content
  end

  # ==============================================================================
  # POST /api/v1/accounts/:account_id/contacts/:contact_id/contact_trackings/:id/pause
  # ==============================================================================
  # Descripción: Pausa la ejecución de un seguimiento activo o programado
  # ==============================================================================
  def pause
    if @tracking.pause!
      render json: { 
        message: I18n.t('api.contact_trackings.paused'),
        tracking: tracking_json(@tracking)
      }
    else
      render json: { 
        error: I18n.t('api.contact_trackings.cannot_pause')
      }, status: :unprocessable_entity
    end
  end

  # ==============================================================================
  # POST /api/v1/accounts/:account_id/contacts/:contact_id/contact_trackings/:id/resume
  # ==============================================================================
  # Descripción: Reanuda la ejecución de un seguimiento pausado
  # Parámetros:
  #   - scheduled_for (opcional): Fecha/hora del siguiente intento
  #     Si no se proporciona, se calcula automáticamente
  # ==============================================================================
  def resume
    # Obtener fecha del siguiente intento (opcional)
    new_scheduled_time = nil
    if params[:scheduled_for].present?
      new_scheduled_time = Time.zone.parse(params[:scheduled_for])
    end

    if @tracking.resume!(new_scheduled_time)
      render json: {
        message: I18n.t('api.contact_trackings.resumed'),
        tracking: tracking_json(@tracking)
      }
    else
      error_message = @tracking.errors.full_messages.join(', ')
      error_message = I18n.t('api.contact_trackings.cannot_resume') if error_message.blank?
      render json: {
        error: error_message
      }, status: :unprocessable_entity
    end
  end

  # ==============================================================================
  # POST /api/v1/accounts/:account_id/contacts/:contact_id/contact_trackings/:id/cancel
  # ==============================================================================
  # Descripción: Cancela permanentemente un seguimiento
  # Nota: Los seguimientos cancelados no pueden ser reactivados
  # ==============================================================================
  def cancel
    if @tracking.cancel!
      render json: {
        message: I18n.t('api.contact_trackings.cancelled'),
        tracking: tracking_json(@tracking)
      }
    else
      render json: {
        error: I18n.t('api.contact_trackings.cannot_cancel')
      }, status: :unprocessable_entity
    end
  end

  # ==============================================================================
  # POST /api/v1/accounts/:account_id/contacts/:contact_id/contact_trackings/improve_text
  # ==============================================================================
  # Descripción: Mejora la redacción de un texto usando IA
  # Parámetros:
  #   - text: Texto a mejorar
  # ==============================================================================
  def improve_text
    text = params[:text]&.strip
    mode = params[:mode] || 'improve'

    if text.blank?
      render json: { error: 'El texto es requerido' }, status: :unprocessable_entity
      return
    end

    begin
      improved = case mode
                 when 'generate_prompt'
                   generate_prompt_with_ai(text, params[:context], params[:objective])
                 when 'process_contact_context' # proyecto@contacts_notes - modo para estructurar notas como contexto IA
                   process_contact_context_with_ai(text)
                 else
                   improve_text_with_ai(text)
                 end
      render json: { improved_text: improved }
    rescue StandardError => e
      Rails.logger.error "[ImproveText] Error: #{e.message}"
      render json: { error: 'Error al procesar el texto' }, status: :internal_server_error
    end
  end

  private

  # ==============================================================================
  # Private Methods - Setters
  # ==============================================================================

  def set_contact
    @contact = Current.account.contacts.find(params[:contact_id])
  end

  def set_tracking
    @tracking = @contact.contact_trackings
                        .where(account_id: Current.account.id)
                        .find(params[:id])
  end

  # ==============================================================================
  # Private Methods - Autorización
  # ==============================================================================

  def authorize_inbox_access
    inbox_id = params[:contact_tracking]&.dig(:inbox_id) || params[:inbox_id]
    return unless inbox_id

    inbox = Current.account.inboxes.find_by(id: inbox_id)

    unless inbox && Current.user.assigned_inboxes.include?(inbox)
      render json: {
        error: I18n.t('api.contact_trackings.unauthorized_inbox')
      }, status: :forbidden
    end
  end

  # ==============================================================================
  # Private Methods - Resolución de IDs
  # ==============================================================================

  # ⭐ Convierte display_id a id real de conversación (compatibilidad frontend)
  # El frontend envía display_id como conversation_id, pero la BD usa el id real
  # Busca SOLO en las conversaciones del contacto para evitar colisiones de IDs
  def resolve_conversation_id(conversation_id)
    return nil if conversation_id.blank?

    # Buscar solo en conversaciones del contacto (más seguro)
    conversation = @contact.conversations.find_by(display_id: conversation_id) ||
                   @contact.conversations.find_by(id: conversation_id)
    conversation&.id
  end

  # ==============================================================================
  # Private Methods - Parámetros permitidos (⭐ ACTUALIZADO)
  # ==============================================================================

  def tracking_params
    params.require(:contact_tracking).permit(
      :objective,
      :scheduled_for,
      :max_attempts,
      :interval_days,              # Legacy - mantener por compatibilidad
      :retry_interval_value,       # ⭐ NUEVO
      :retry_interval_unit,        # ⭐ NUEVO
      :inbox_id,
      :conversation_id,
      :ai_context,
      :complementary_prompt,       # ⭐ NUEVO - Instrucciones adicionales para responder preguntas
      :quote_id,
      :status,
      whatsapp_templates: [],        # ⭐ NUEVO - Array de strings
      keyword_actions: [:keyword, :action, :direction] # proyecto@contact_tracking
    )
  end

  # ==============================================================================
  # Private Methods - Serialización JSON (⭐ ACTUALIZADO)
  # ==============================================================================

  def tracking_json(tracking)
    {
      id: tracking.id,
      contact_id: tracking.contact_id,
      conversation_id: tracking.conversation_id,
      inbox_id: tracking.inbox_id,
      inbox_name: tracking.inbox&.name,
      objective: tracking.objective,
      scheduled_for: tracking.scheduled_for,
      max_attempts: tracking.max_attempts,
      attempt_count: tracking.attempt_count,
      attempts_remaining: tracking.attempts_remaining,
      
      # Legacy - mantener por compatibilidad
      interval_days: tracking.interval_days,
      
      # ⭐ NUEVO: Campos de retry_interval
      retry_interval_value: tracking.retry_interval_value,
      retry_interval_unit: tracking.retry_interval_unit,
      
      # ⭐ NUEVO: Plantillas WhatsApp
      whatsapp_templates: tracking.whatsapp_templates || [],

      # proyecto@contact_tracking: palabras clave de acción
      keyword_actions: tracking.keyword_actions || [],
      
      # Campos existentes
      ai_context: tracking.ai_context,
      complementary_prompt: tracking.complementary_prompt,  # ⭐ NUEVO - Instrucciones para preguntas
      quote_id: tracking.quote_id,
      status: tracking.status,
      paused_at: tracking.paused_at,  # ⭐ NUEVO - Fecha/hora de pausa
      last_attempt_at: tracking.last_attempt_at,
      last_message_sent: tracking.last_message_sent,
      last_error: tracking.last_error,
      created_at: tracking.created_at,
      updated_at: tracking.updated_at
    }
  end

  # ==============================================================================
  # Private Methods - Paginación
  # ==============================================================================

  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      next_page: collection.next_page,
      prev_page: collection.prev_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count
    }
  end

  # ==============================================================================
  # Private Methods - IA
  # ==============================================================================

  def get_openai_api_key
    # Prioridad 1: Integración de cuenta
    hook = Current.account.hooks.find_by(app_id: 'openai', status: 'enabled')
    return hook.settings['api_key'] if hook && hook.settings['api_key'].present?

    # Prioridad 2: ENV
    ENV['OPENAI_API_KEY']
  end

  def improve_text_with_ai(text)
    api_key = get_openai_api_key
    raise 'API key de OpenAI no configurada' unless api_key.present?

    require 'net/http'
    require 'json'

    uri = URI('https://api.openai.com/v1/chat/completions')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 15

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'

    prompt = <<~PROMPT
      Eres un asistente experto en redacción profesional en español.
      Tu tarea es mejorar la redacción del texto proporcionado:
      - Corrige errores ortográficos y gramaticales
      - Mejora la claridad y fluidez
      - Mantén el significado original intacto
      - Conserva el tono (formal/informal) del texto original
      - NO agregues información nueva
      - NO cambies el propósito del texto
      - Responde SOLO con el texto mejorado, sin explicaciones

      TEXTO A MEJORAR:
      #{text}
    PROMPT

    request.body = {
      model: 'gpt-4o-mini',
      messages: [{ role: 'user', content: prompt }],
      max_tokens: 1000,
      temperature: 0.3
    }.to_json

    response = http.request(request)
    response_body = JSON.parse(response.body)

    improved = response_body.dig('choices', 0, 'message', 'content')&.strip
    improved.presence || text
  end

  def generate_prompt_with_ai(text, context = nil, objective = nil)
    api_key = get_openai_api_key
    raise 'API key de OpenAI no configurada' unless api_key.present?

    require 'net/http'
    require 'json'

    uri = URI('https://api.openai.com/v1/chat/completions')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 15

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'

    prompt = <<~PROMPT
      Eres un generador de prompts para un BOT DE SEGUIMIENTOS EMPRESARIAL.

      Tu responsabilidad es:
      1. Analizar el CONTEXTO y DATOS proporcionados
      2. Construir un PROMPT OPERATIVO FINAL que defina:
         – Comportamiento del bot
         – Qué debe comunicar
         – Qué NO debe hacer
         – Tono
         – Objetivo del seguimiento

      REGLAS ABSOLUTAS:
      – NO inventes información
      – NO modifiques los datos proporcionados
      – NO agregues ofertas, fechas o montos no indicados
      – NO hagas preguntas al usuario final
      – El mensaje debe ser claro, breve y orientado a acción
      – El bot actúa como un asesor comercial profesional, no como un chatbot genérico

      FORMATO OBLIGATORIO DE SALIDA (respetar exactamente esta estructura):

      ROL:
      [Descripción del rol del bot en una oración]

      OBJETIVO:
      [Objetivo del seguimiento en una oración]

      INFORMACIÓN A COMUNICAR:
      - [Dato 1]
      - [Dato 2]
      - [Dato N]

      LLAMADO A ACCIÓN:
      [Acción que se espera del cliente]

      TONO:
      [Descripción del tono en una oración]

      PROHIBICIONES:
      - [Prohibición 1]
      - [Prohibición 2]
      - [Prohibición N]

      Genera ÚNICAMENTE el PROMPT OPERATIVO FINAL con el formato indicado.
      NO incluyas explicaciones ni encabezados adicionales.
      Cada sección debe estar separada por una línea en blanco.

      DATOS DEL SEGUIMIENTO:

      OBJETIVO: #{objective.presence || 'No especificado'}

      CONTEXTO: #{context.presence || 'No especificado'}

      INSTRUCCIONES ADICIONALES: #{text.presence || 'Ninguna'}
    PROMPT

    request.body = {
      model: 'gpt-4o-mini',
      messages: [{ role: 'user', content: prompt }],
      max_tokens: 1500,
      temperature: 0.3
    }.to_json

    response = http.request(request)
    response_body = JSON.parse(response.body)

    generated = response_body.dig('choices', 0, 'message', 'content')&.strip
    generated.presence || text
  end

  def process_contact_context_with_ai(text)
    api_key = get_openai_api_key
    raise 'API key de OpenAI no configurada' unless api_key.present?

    require 'net/http'
    require 'json'

    uri = URI('https://api.openai.com/v1/chat/completions')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 15

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'

    prompt = <<~PROMPT
      Eres un procesador de contexto de contactos para un sistema de seguimientos empresarial con IA.

      Tu tarea es tomar las notas redactadas por el agente y transformarlas en un CONTEXTO ESTRUCTURADO
      que pueda ser consumido eficientemente por una IA en futuros procesos de seguimiento.

      REGLAS:
      - Organiza la información en secciones claras y etiquetadas
      - Extrae datos clave: intereses, historial, preferencias, objeciones, estado actual
      - Elimina información irrelevante o redundante
      - Usa lenguaje conciso y directo, orientado a datos
      - NO inventes ni supongas información que no esté en el texto original
      - Responde ÚNICAMENTE con el contexto estructurado, sin explicaciones adicionales

      FORMATO DE SALIDA:
      INTERÉS: [producto o servicio de interés]
      HISTORIAL: [interacciones previas relevantes]
      PREFERENCIAS: [preferencias o requisitos detectados]
      OBJECIONES: [objeciones o puntos de resistencia]
      ESTADO ACTUAL: [situación actual del contacto en el proceso]
      NOTAS ADICIONALES: [cualquier otro dato relevante]

      NOTAS DEL AGENTE:
      #{text}
    PROMPT

    request.body = {
      model: 'gpt-4o-mini',
      messages: [{ role: 'user', content: prompt }],
      max_tokens: 1200,
      temperature: 0.2
    }.to_json

    response = http.request(request)
    response_body = JSON.parse(response.body)

    processed = response_body.dig('choices', 0, 'message', 'content')&.strip
    processed.presence || text
  end
end