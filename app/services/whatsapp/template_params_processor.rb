# frozen_string_literal: true

# ================================================================================
# proyecto@contact_tracking
# ================================================================================
# Servicio: TemplateParamsProcessor
# Descripción: Procesa y mapea automáticamente parámetros de plantillas WhatsApp HSM
#              Soporta DOS formatos:
#              1. Variables Liquid: {{contact.name}}, {{contact.custom_attributes.empresa}}
#              2. Parámetros numerados: {{1}}, {{2}} (legacy/fallback)
# ================================================================================

module Whatsapp
  class TemplateParamsProcessor
    attr_reader :tracking, :template, :contact, :errors

    # ============================================================================
    # MAPEO DE VARIABLES LIQUID SOPORTADAS
    # ============================================================================
    # Formato: {{objeto.propiedad}} o {{objeto.propiedad.subpropiedad}}
    #
    # Variables de Contacto:
    #   {{contact.name}}                    - Nombre completo
    #   {{contact.first_name}}              - Primer nombre
    #   {{contact.last_name}}               - Apellido
    #   {{contact.email}}                   - Correo electrónico
    #   {{contact.phone_number}}            - Teléfono
    #   {{contact.custom_attributes.X}}     - Atributo personalizado X
    #
    # Variables de Conversación:
    #   {{conversation.id}}                 - ID de conversación
    #   {{conversation.custom_attributes.X}} - Atributo personalizado X
    #
    # Variables de Tracking:
    #   {{tracking.objective}}              - Objetivo del seguimiento
    #   {{tracking.ai_context}}             - Contexto IA
    #
    # Variables de Sistema:
    #   {{current_date}}                    - Fecha actual (DD/MM/YYYY)
    #   {{current_time}}                    - Hora actual (HH:MM)
    # ============================================================================

    # Patrones para detectar tipo de dato (fallback para {{1}}, {{2}})
    VARIABLE_PATTERNS = {
      name: /nombre|name|cliente|customer/i,
      first_name: /primer.*nombre|first.*name/i,
      phone: /tel[eé]fono|phone|celular|m[oó]vil/i,
      email: /correo|email|e-mail/i,
      company: /empresa|company|negocio|compa[ñn][ií]a/i,
      date: /fecha|date|d[ií]a/i,
      time: /hora|time|horario/i,
      amount: /monto|amount|precio|total|importe/i,
      product: /producto|product|servicio|service/i,
      order: /orden|order|pedido|cotizaci[oó]n|quote/i
    }.freeze

    def initialize(tracking, template_name)
      @tracking = tracking
      @template_name = template_name
      @contact = tracking.contact
      @conversation = tracking.conversation
      @errors = []
      @template = find_template(template_name)
    end

    # ============================================================================
    # MÉTODO PRINCIPAL: Procesar parámetros
    # ============================================================================
    def process
      return error_result('Plantilla no encontrada') unless @template
      return error_result('Plantilla no aprobada') unless template_approved?

      body_component = get_body_component
      return error_result('Plantilla sin componente BODY') unless body_component

      body_text = body_component['text']
      return success_result([]) unless body_text.include?('{{')

      # ⭐ DETECTAR TIPO DE PARÁMETROS
      if uses_liquid_variables?(body_text)
        process_liquid_params(body_text)
      else
        process_numbered_params(body_text)
      end
    end

    # ============================================================================
    # Validar plantilla antes de usar (para frontend)
    # ============================================================================
    def validate
      result = process
      {
        valid: result[:success],
        template_name: @template_name,
        template_body: get_template_body_text,
        param_count: get_param_count,
        param_type: get_param_type,
        errors: result[:errors],
        available_data: available_data_summary
      }
    end

    private

    # ============================================================================
    # Detectar si usa variables Liquid ({{contact.name}}) o numeradas ({{1}})
    # ============================================================================
    def uses_liquid_variables?(body_text)
      # Detecta patrones como {{contact.name}}, {{contact.custom_attributes.factura_monto_568}}, etc.
      # Soporta números en nombres de atributos
      body_text.match?(/\{\{[a-z_][a-z0-9_]*\.[a-z0-9_\.]+\}\}/i)
    end

    def get_param_type
      body_text = get_template_body_text
      return 'none' unless body_text
      uses_liquid_variables?(body_text) ? 'liquid' : 'numbered'
    end

    # ============================================================================
    # PROCESAR VARIABLES LIQUID: {{contact.name}}, {{contact.custom_attributes.X}}
    # ============================================================================
    def process_liquid_params(body_text)
      # Extraer todas las variables Liquid (soporta números en nombres: factura_monto_568)
      liquid_vars = body_text.scan(/\{\{([a-z_][a-z0-9_]*(?:\.[a-z_][a-z0-9_]*)+)\}\}/i).flatten

      return success_result([]) if liquid_vars.empty?

      processed_params = []
      liquid_vars.each do |var_path|
        value = resolve_liquid_variable(var_path)

        if value.blank?
          @errors << "Variable {{#{var_path}}} no tiene valor"
          # ⚠️ WhatsApp API solo acepta { type: 'text', text: 'valor' }
          # NO incluir keys adicionales como 'variable'
          processed_params << { type: 'text', text: '' }
        else
          processed_params << { type: 'text', text: value.to_s }
        end
      end

      if @errors.any?
        error_result(@errors.join(', '), processed_params)
      else
        success_result(processed_params)
      end
    end

    # ============================================================================
    # RESOLVER VARIABLE LIQUID
    # ============================================================================
    def resolve_liquid_variable(var_path)
      parts = var_path.downcase.split('.')
      root = parts.shift

      case root
      when 'contact'
        resolve_contact_variable(parts)
      when 'conversation'
        resolve_conversation_variable(parts)
      when 'tracking'
        resolve_tracking_variable(parts)
      when 'current_date'
        Time.current.strftime('%d/%m/%Y')
      when 'current_time'
        Time.current.strftime('%H:%M')
      else
        nil
      end
    end

    def resolve_contact_variable(parts)
      return nil if parts.empty?

      property = parts.shift

      case property
      when 'name'
        @contact.name
      when 'first_name'
        @contact.name&.split&.first&.capitalize
      when 'last_name'
        @contact.name&.split&.drop(1)&.join(' ')
      when 'email'
        @contact.email
      when 'phone_number', 'phone'
        @contact.phone_number
      when 'custom_attributes'
        # Soporta: contact.custom_attributes.empresa
        attr_key = parts.shift
        return nil unless attr_key
        @contact.custom_attributes&.dig(attr_key) ||
        @contact.custom_attributes&.dig(attr_key.to_sym)
      else
        # Intentar como atributo directo del contacto
        @contact.try(property) || @contact.custom_attributes&.dig(property)
      end
    end

    def resolve_conversation_variable(parts)
      return nil if parts.empty? || @conversation.nil?

      property = parts.shift

      case property
      when 'id'
        @conversation.id
      when 'display_id'
        @conversation.display_id
      when 'custom_attributes'
        attr_key = parts.shift
        return nil unless attr_key
        @conversation.custom_attributes&.dig(attr_key) ||
        @conversation.custom_attributes&.dig(attr_key.to_sym)
      else
        @conversation.try(property)
      end
    end

    def resolve_tracking_variable(parts)
      return nil if parts.empty?

      property = parts.shift

      case property
      when 'objective'
        @tracking.objective
      when 'ai_context'
        @tracking.ai_context
      when 'quote_id'
        @tracking.quote_id
      else
        @tracking.try(property)
      end
    end

    # ============================================================================
    # PROCESAR PARÁMETROS NUMERADOS (Legacy): {{1}}, {{2}}, {{3}}
    # ============================================================================
    def process_numbered_params(body_text)
      param_count = body_text.scan(/\{\{(\d+)\}\}/).flatten.map(&:to_i).max || 0
      return success_result([]) if param_count.zero?

      processed_params = []
      (1..param_count).each do |param_num|
        value = resolve_numbered_parameter(param_num, body_text)

        if value.blank?
          @errors << "Parámetro {{#{param_num}}} no tiene valor asignado"
          processed_params << { type: 'text', text: '' }
        else
          processed_params << { type: 'text', text: value.to_s }
        end
      end

      if @errors.any?
        error_result(@errors.join(', '), processed_params)
      else
        success_result(processed_params)
      end
    end

    # ============================================================================
    # Buscar plantilla en el canal
    # ============================================================================
    def find_template(template_name)
      channel = @tracking.inbox.channel
      return nil unless channel.respond_to?(:message_templates)
      return nil unless channel.message_templates.is_a?(Array)

      channel.message_templates.find { |t| t['name'] == template_name }
    end

    def template_approved?
      @template['status'] == 'approved' || @template['status'] == 'APPROVED'
    end

    def get_body_component
      @template['components']&.find { |c| c['type'] == 'BODY' }
    end

    def get_template_body_text
      get_body_component&.dig('text')
    end

    def get_param_count
      body_text = get_template_body_text
      return 0 unless body_text

      if uses_liquid_variables?(body_text)
        # Soporta números en nombres de atributos (ej: factura_monto_568)
        body_text.scan(/\{\{[a-z_][a-z0-9_]*(?:\.[a-z_][a-z0-9_]*)+\}\}/i).length
      else
        body_text.scan(/\{\{(\d+)\}\}/).flatten.map(&:to_i).max || 0
      end
    end

    # ============================================================================
    # Resolver valor de parámetro numerado (legacy)
    # ============================================================================
    def resolve_numbered_parameter(param_num, body_text)
      # ⭐ PRIORIDAD 1: {{1}} SIEMPRE es el nombre del contacto
      # Esta es la convención más común en plantillas WhatsApp
      if param_num == 1
        return @contact.name if @contact.name.present?
        return @contact.phone_number if @contact.phone_number.present?
      end

      # Estrategia 2: Para otros parámetros, intentar detectar contexto
      context_value = detect_from_context(param_num, body_text)
      return context_value if context_value.present?

      # Estrategia 3: Mapeo por posición común
      positional_value = map_by_position(param_num)
      return positional_value if positional_value.present?

      nil
    end

    # ============================================================================
    # Detectar valor basándose en el contexto del texto
    # ============================================================================
    def detect_from_context(param_num, body_text)
      pattern = /(.{0,30})\{\{#{param_num}\}\}(.{0,30})/
      match = body_text.match(pattern)

      return nil unless match

      # ⭐ IMPORTANTE: Solo analizar el texto ANTES del parámetro
      # El texto después puede contener palabras que confundan la detección
      # Ejemplo: "Hola {{1}}, tu cotización..." - "cotización" NO describe {{1}}
      context_before = match[1].to_s.downcase.strip

      # Solo usar contexto después si es muy corto (como ":" o "es")
      context_after = match[2].to_s.downcase.strip
      context_after = '' if context_after.length > 5

      full_context = "#{context_before} #{context_after}".strip

      VARIABLE_PATTERNS.each do |type, regex|
        if full_context.match?(regex)
          return get_value_for_type(type)
        end
      end

      nil
    end

    # ============================================================================
    # Obtener valor según el tipo detectado
    # ============================================================================
    def get_value_for_type(type)
      case type
      when :name
        @contact.name
      when :first_name
        @contact.name&.split&.first&.capitalize
      when :phone
        @contact.phone_number
      when :email
        @contact.email
      when :company
        @contact.custom_attributes&.dig('company') ||
        @contact.custom_attributes&.dig('empresa')
      when :date
        Time.current.strftime('%d/%m/%Y')
      when :time
        Time.current.strftime('%H:%M')
      when :amount
        get_custom_attribute('amount', 'monto', 'importe', 'total', 'precio')
      when :product
        get_custom_attribute('product', 'producto', 'servicio')
      when :order
        get_custom_attribute('order_id', 'order', 'pedido', 'cotizacion', 'quote_id') ||
        @tracking.ai_context&.match(/(?:cotización|orden|pedido)[:\s#]*(\w+)/i)&.[](1)
      else
        nil
      end
    end

    # ============================================================================
    # Mapeo por posición (convención común)
    # ============================================================================
    def map_by_position(param_num)
      case param_num
      when 1
        # {{1}} casi siempre es el nombre del cliente
        @contact.name || @contact.phone_number
      when 2
        # {{2}} puede ser producto, servicio, o referencia
        extract_reference_from_context
      when 3
        # {{3}} puede ser fecha, monto, u otro dato
        extract_secondary_data
      else
        # Parámetros adicionales: intentar con atributos personalizados
        nil
      end
    end

    # ============================================================================
    # Extraer referencia del contexto del tracking
    # ============================================================================
    def extract_reference_from_context
      context = @tracking.ai_context.to_s + ' ' + @tracking.objective.to_s

      # Buscar patrones comunes de referencia
      patterns = [
        /cotizaci[oó]n[:\s#]*([A-Z0-9-]+)/i,
        /orden[:\s#]*([A-Z0-9-]+)/i,
        /pedido[:\s#]*([A-Z0-9-]+)/i,
        /factura[:\s#]*([A-Z0-9-]+)/i,
        /ticket[:\s#]*([A-Z0-9-]+)/i,
        /referencia[:\s#]*([A-Z0-9-]+)/i
      ]

      patterns.each do |pattern|
        match = context.match(pattern)
        return match[1] if match
      end

      # Fallback: objetivo resumido
      @tracking.objective&.truncate(50)
    end

    def extract_secondary_data
      # Intentar extraer fecha, monto u otro dato del contexto
      context = @tracking.ai_context.to_s

      # Buscar monto
      if (match = context.match(/\$[\d,.]+|\d+[\d,.]*\s*(pesos|mxn|usd)/i))
        return match[0]
      end

      # Buscar fecha
      if (match = context.match(/\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}/))
        return match[0]
      end

      nil
    end

    # ============================================================================
    # Buscar en atributos personalizados
    # ============================================================================
    def get_custom_attribute(*keys)
      contact_attrs = @contact.custom_attributes || {}
      conversation_attrs = @conversation&.custom_attributes || {}

      keys.each do |key|
        value = contact_attrs[key] || contact_attrs[key.to_s] ||
                conversation_attrs[key] || conversation_attrs[key.to_s]
        return value if value.present?
      end

      nil
    end

    # ============================================================================
    # Resumen de datos disponibles (para debug/UI)
    # ============================================================================
    def available_data_summary
      {
        contact: {
          name: @contact.name,
          first_name: @contact.name&.split&.first,
          email: @contact.email,
          phone_number: @contact.phone_number,
          custom_attributes: @contact.custom_attributes&.keys || []
        },
        tracking: {
          objective: @tracking.objective&.truncate(100),
          ai_context_preview: @tracking.ai_context&.truncate(100)
        },
        conversation: {
          custom_attributes: @conversation&.custom_attributes&.keys || []
        }
      }
    end

    # ============================================================================
    # Formatear resultados
    # ============================================================================
    def success_result(params)
      {
        success: true,
        parameters: params,
        errors: []
      }
    end

    def error_result(message, params = [])
      {
        success: false,
        parameters: params,
        errors: [message].flatten
      }
    end
  end
end
