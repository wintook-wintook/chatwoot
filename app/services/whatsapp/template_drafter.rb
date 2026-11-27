# frozen_string_literal: true

# Plantillas de WhatsApp — «Crear con IA». De lo que el usuario quiere lograr arma un
# borrador del formulario dentro de las reglas de Meta:
#   - nombre estructurado (área_propósito_detalle), único en la cuenta;
#   - categoría (utilidad o marketing) con su porqué;
#   - encabezado de texto, cuerpo, pie y botones de respuesta rápida;
#   - variables con nombre ligadas a los datos del contacto, y sus ejemplos.
# No guarda ni manda nada a Meta, y el canal lo elige el usuario. Pasa por
# Whatsapp::TemplateValidator; si algo no cumple, se le pide una vez a la IA que lo
# corrija. Usa la integración OpenAI de la cuenta (Cases::Ai::BaseService).
#   Whatsapp::TemplateDrafter.new(account:).call(goal:, tone:, language:, previous:, adjust:)
#     → { draft: {...}, reason:, warnings: [] } | { error: }
class Whatsapp::TemplateDrafter < Cases::Ai::BaseService
  TONES = %w[cercano formal directo].freeze
  AREAS = %w[ventas cobranza soporte servicio citas pedidos marketing general].freeze
  RESERVED = { 'nombre' => 'nombre completo del contacto', 'primer_nombre' => 'primer nombre del contacto',
               'apellido' => 'apellido', 'correo' => 'correo', 'telefono' => 'teléfono', 'empresa' => 'empresa del contacto',
               'agente' => 'nombre del agente que atiende', 'fecha_hoy' => 'fecha de hoy' }.freeze
  MAX_NAME = 60
  MAX_QUICK_REPLIES = 3
  Draft = Struct.new(:name, :category, :language, :header_type, :header_content, :header_media_url, :header_handle,
                     :header_sample, :body_text, :footer_text, :buttons, :sample_values, keyword_init: true)

  def call(goal:, tone: nil, language: 'es', previous: nil, adjust: nil)
    return error('no_key') unless available?
    return error('goal_required') if goal.to_s.strip.blank?

    raw = ask(user_prompt(goal, tone, previous, adjust))
    return error('failed') unless raw

    draft = normalize(raw, language)
    errors = validate(draft)
    if errors.any?
      fixed = ask(fix_prompt(raw, errors))
      draft = normalize(fixed, language) if fixed
      raw = fixed || raw
      errors = validate(draft)
    end
    { draft: draft, reason: raw['category_reason'].to_s.strip, warnings: errors, manual_variables: manual_variables(draft) }
  end

  private

  def ask(prompt)
    raw = chat(system: system_prompt, user: prompt, json: true, temperature: 0.4, max_tokens: 1200)
    raw.is_a?(Hash) ? raw : nil
  end

  def error(key)
    { error: I18n.with_locale(@account.locale.presence || I18n.default_locale) { I18n.t("whatsapp_templates.ai.#{key}") } }
  end

  def system_prompt
    <<~PROMPT
      Eres experto en plantillas de WhatsApp Business (Meta). Con lo que el usuario quiere lograr, propones UNA
      plantilla lista para revisión de Meta, en el idioma pedido, natural y breve. Responde SOLO JSON:
      {"name": "...", "category": "UTILITY|MARKETING", "category_reason": "una línea de por qué",
       "header": "texto corto o vacío", "body": "...", "footer": "texto o vacío",
       "buttons": ["texto botón respuesta rápida", ...], "samples": {"variable": "ejemplo", ...}}
      Reglas:
      - name: minúsculas, sin acentos, palabras unidas con guion bajo, forma área_propósito_detalle (máx 5 palabras).
        Áreas: #{AREAS.join(', ')}. Ej.: ventas_cotizacion_por_vencer, cobranza_recordatorio_pago.
      - category: UTILITY si avisa o da seguimiento a algo que el cliente ya tiene (pedido, cita, pago, cotización,
        caso); MARKETING si promueve, ofrece o reactiva.
      - Variables entre dobles llaves. Del contacto usa estas claves: #{variable_list}. Si hace falta otro dato
        (fecha de entrega, monto, folio…), crea una clave clara en minúsculas con guion bajo (ej. fecha_entrega,
        monto_total). Nunca uses una clave para otra cosa (fecha_hoy es solo la fecha de hoy).
      - Nunca empieces ni termines el cuerpo con una variable, ni pongas dos variables seguidas.
      - body: máximo 550 caracteres, empieza con el saludo, sin enlaces inventados.
      - header: opcional; un título corto del tema (ej. «Tu cotización por vencer»), nunca el saludo; máximo 60,
        sin emojis ni saltos. footer: opcional, máximo 60, sin variables (ej. el nombre del negocio no va como variable).
      - buttons: 0 a #{MAX_QUICK_REPLIES} respuestas rápidas de máximo 25 caracteres (ej. «Sí, me interesa»).
      - samples: un ejemplo realista por cada variable usada (header y body).
    PROMPT
  end

  def variable_list
    extra = custom_attributes.map { |key, label| "#{key} (#{label})" }
    (RESERVED.map { |key, label| "#{key} (#{label})" } + extra).join(', ')
  end

  def custom_attributes
    @custom_attributes ||= @account.custom_attribute_definitions.where(attribute_model: 'contact_attribute')
                                   .pluck(:attribute_key, :attribute_display_name)
                                   .select { |key, _| key.to_s.match?(/\A[a-z][a-z0-9_]*\z/) }
  end

  def user_prompt(goal, tone, previous, adjust)
    lines = ["Lo que quiero lograr: #{goal.to_s.strip.first(800)}"]
    lines << "Tono: #{tone}" if TONES.include?(tone.to_s)
    if previous.present? && adjust.present?
      lines << "Propuesta anterior: #{previous.to_json.first(3000)}"
      lines << "Ajústala así: #{adjust.to_s.strip.first(400)}"
    elsif previous.present?
      lines << "Ya te propusieron esto; da otra propuesta distinta: #{previous.to_json.first(3000)}"
    end
    lines.join("\n")
  end

  def fix_prompt(raw, errors)
    "Corrige esta plantilla para que cumpla las reglas. Problemas: #{errors.join('; ')}\nPlantilla: #{raw.to_json.first(3000)}"
  end

  def normalize(raw, language)
    header = raw['header'].to_s.gsub(/\s+/, ' ').strip.first(60)
    body = raw['body'].to_s.strip.first(1024)
    { name: unique_name(raw['name']), category: raw['category'].to_s.casecmp('MARKETING').zero? ? 'MARKETING' : 'UTILITY',
      language: language.presence || 'es', header_type: header.present? ? 'text' : '', header_content: header,
      body_text: body, footer_text: raw['footer'].to_s.gsub(/\{\{[^}]*\}\}/, '').strip.first(60),
      buttons: buttons(raw['buttons']), sample_values: sample_values(raw, header, body) }
  end

  def sample_values(raw, header, body)
    samples = raw['samples'].is_a?(Hash) ? raw['samples'].transform_keys(&:to_s) : {}
    { 'body' => samples_for(body, samples), 'header' => samples_for(header, samples) }
  end

  def buttons(list)
    Array(list).map { |b| b.is_a?(Hash) ? b['text'] : b }.map { |t| t.to_s.strip.first(25) }.compact_blank
               .first(MAX_QUICK_REPLIES)
               .map { |text| { 'type' => 'QUICK_REPLY', 'text' => text, 'url' => '', 'phone_number' => '', 'example' => [] } }
  end

  # Los ejemplos en el orden de las variables (como los espera el formulario y Meta).
  def samples_for(text, samples)
    Whatsapp::TemplateVariables.tokens(text).uniq.map { |key| samples[key].to_s.strip.presence || key.tr('_', ' ') }
  end

  # Las que no salen de los datos del contacto: se llenan al enviar.
  def manual_variables(draft)
    known = RESERVED.keys + custom_attributes.map(&:first) + %w[bandeja conversacion]
    (Whatsapp::TemplateVariables.tokens(draft[:header_content]) + Whatsapp::TemplateVariables.tokens(draft[:body_text]))
      .uniq.reject { |key| known.include?(key) || key.match?(/\A\d+\z/) }
  end

  def unique_name(name)
    base = I18n.transliterate(name.to_s).downcase.gsub(/[^a-z0-9]+/, '_').gsub(/\A_+|_+\z/, '').first(MAX_NAME)
    base = 'general_plantilla' if base.blank?
    taken = existing_names
    return base unless taken.include?(base)

    (2..99).map { |n| "#{base.first(MAX_NAME - 4)}_v#{n}" }.find { |candidate| taken.exclude?(candidate) }
  end

  def existing_names
    names = @account.whatsapp_templates.pluck(:name)
    @account.inboxes.map(&:channel).grep(Channel::Whatsapp).each do |channel|
      names.concat(Array(channel.message_templates).pluck('name'))
    end
    names.to_set
  end

  def validate(draft)
    Whatsapp::TemplateValidator.call(Draft.new(**draft)).errors
  end
end
