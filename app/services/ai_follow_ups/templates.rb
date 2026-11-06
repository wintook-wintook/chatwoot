# frozen_string_literal: true

# Seguimiento IA — las plantillas de WhatsApp con las que el agente puede reabrir la ventana
# de 24 h, y su llenado.
#
#   t = AiFollowUps::Templates.new(conversation)
#   t.available            → [{ name:, language:, namespace:, category:, body:, variables: }] (aprobadas y usables)
#   t.find(name, language) → la plantilla o nil
#   t.fill(name, language, values) → { content:, template_params: } | { error: }
#
# Usables en esta primera versión: aprobadas, con cuerpo, sin archivo en el encabezado, sin
# variables en el encabezado ni en los botones, y que no sean de autenticación. Las variables
# del cuerpo las llena el modelo; aquí se valida que estén todas y se limpian (Meta rechaza
# saltos de línea y tabuladores en los parámetros).
class AiFollowUps::Templates
  MAX_VALUE = 200
  SKIP_CATEGORIES = %w[AUTHENTICATION].freeze
  DYNAMIC_BUTTONS = %w[COPY_CODE OTP FLOW CATALOG MPM].freeze

  def initialize(conversation)
    @conversation = conversation
    @channel = conversation&.inbox&.channel
  end

  def whatsapp?
    @channel.is_a?(Channel::Whatsapp)
  end

  def available
    return [] unless whatsapp?

    Array(@channel.message_templates).select { |t| usable?(t) }.map { |t| describe(t) }
  end

  def find(name, language = nil)
    available.find do |t|
      t[:name] == name.to_s && (language.blank? || t[:language].to_s.casecmp?(language.to_s))
    end
  end

  def fill(name, language, values)
    template = find(name, language)
    return { error: "La plantilla «#{name}» no existe, no está aprobada o no se puede usar aquí." } unless template

    values = clean(values)
    missing = template[:variables] - values.keys
    return { error: "Faltan variables: #{missing.join(', ')}. Llénalas con datos reales." } if missing.any?

    used = values.slice(*template[:variables])
    { template: template, content: render(template[:body], used), template_params: params_for(template, used) }
  end

  private

  def usable?(template)
    return false unless template['status'].to_s.casecmp?('approved')
    return false if SKIP_CATEGORIES.include?(template['category'].to_s.upcase)

    components = Array(template['components'])
    body = component(components, 'BODY')
    body.present? && plain_header?(components) && plain_buttons?(components)
  end

  def component(components, type)
    Array(components).find { |c| c['type'].to_s.casecmp?(type) }
  end

  def plain_header?(components)
    header = component(components, 'HEADER')
    return true if header.nil?

    header['format'].to_s.upcase.in?(['', 'TEXT']) && Whatsapp::TemplateVariables.tokens(header['text']).empty?
  end

  def plain_buttons?(components)
    buttons = component(components, 'BUTTONS')
    Array(buttons&.dig('buttons')).none? do |b|
      DYNAMIC_BUTTONS.include?(b['type'].to_s.upcase) || Whatsapp::TemplateVariables.tokens(b['url']).any?
    end
  end

  def describe(template)
    body = component(template['components'], 'BODY')['text'].to_s
    { name: template['name'], language: template['language'], namespace: template['namespace'],
      category: template['category'].to_s.upcase, body: body, variables: Whatsapp::TemplateVariables.tokens(body).uniq }
  end

  def clean(values)
    values.to_h.to_h { |k, v| [k.to_s.delete('{} '), v.to_s.gsub(/[\t\r\n]+/, ' ').squeeze(' ').strip.first(MAX_VALUE)] }
          .compact_blank
  end

  def render(body, values)
    body.gsub(Whatsapp::TemplateVariables::TOKEN) { values[Regexp.last_match(1).strip] || Regexp.last_match(0) }
  end

  # WhatsApp Cloud: formato por componentes; 360dialog y UnoAPI: solo el cuerpo, plano.
  def params_for(template, values)
    processed = @channel.provider == 'whatsapp_cloud' ? { 'body' => values } : values
    { 'name' => template[:name], 'language' => template[:language], 'namespace' => template[:namespace],
      'category' => template[:category], 'processed_params' => processed }.compact
  end
end
