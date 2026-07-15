# frozen_string_literal: true

# @waba_templates
# Builder PURO del objeto `template` para ENVIAR una plantilla → POST /{phone_id}/messages.
# Es DISTINTO del de creación: rellena valores reales.
#
# ⚠️ La cabecera multimedia va como `link` (o `id` de /media real), NUNCA como header_handle
#    (Meta rechaza el handle en envío; solo sirve como sample de creación).
#
# Entrada:
#   template → objeto tipo WhatsappTemplate (name, language, header_type, body_text).
#   params   → { body: ['Juan', '$100'],
#                header: 'https://.../img.png'  (media)  |  'Juan' (texto {{1}}),
#                buttons: [ { index: 0, sub_type: 'url', text: 'abc' },
#                           { index: 1, sub_type: 'copy_code', coupon_code: 'ABC123' } ] }
class Whatsapp::TemplateSendComponentBuilder
  MEDIA_KINDS = { 'image' => 'image', 'video' => 'video', 'document' => 'document' }.freeze

  def self.call(template, params = {})
    new(template, params).call
  end

  def initialize(template, params = {})
    @t = template
    @params = (params || {}).with_indifferent_access
  end

  def call
    {
      name: @t.name,
      language: { policy: 'deterministic', code: @t.language },
      components: [header_component, body_component, *button_components].compact
    }
  end

  private

  def header_component
    type = @t.header_type.to_s
    value = @params['header']
    return if type.blank? || value.blank?

    parameter = type == 'text' ? { type: 'text', text: value } : media_parameter(type, value)
    { type: 'header', parameters: [parameter] }
  end

  def media_parameter(type, link)
    kind = MEDIA_KINDS[type]
    { type: kind, kind.to_sym => { link: link } }
  end

  def body_component
    values = Array(@params['body'])
    return if values.empty?

    { type: 'body', parameters: values.map { |v| { type: 'text', text: v } } }
  end

  def button_components
    Array(@params['buttons']).map { |b| button_component(b.with_indifferent_access) }.compact
  end

  def button_component(b)
    sub_type = b['sub_type'].to_s
    parameter =
      case sub_type
      when 'url'       then { type: 'text', text: b['text'] }
      when 'copy_code' then { type: 'coupon_code', coupon_code: b['coupon_code'] }
      end
    return unless parameter

    { type: 'button', sub_type: sub_type, index: b['index'].to_s, parameters: [parameter] }
  end
end
