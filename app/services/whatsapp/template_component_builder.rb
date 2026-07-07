# frozen_string_literal: true

# @waba_templates
# Builder PURO del payload de CREACIÓN de plantilla → POST /{business_account_id}/message_templates.
# Ensambla los components en orden HEADER → BODY → FOOTER → BUTTONS.
#
# OJO: este es el payload de CREACIÓN (usa `example` + `header_handle`), NO el de envío
# (ese va con `link` y valores reales, ver Whatsapp::TemplateSendComponentBuilder).
class Whatsapp::TemplateComponentBuilder
  def self.call(template)
    new(template).call
  end

  def initialize(template)
    @t = template
  end

  # Payload completo para crear la plantilla en Meta.
  def call
    {
      name: @t.name,
      language: @t.language,
      category: @t.category,
      components: components
    }.compact
  end

  def components
    [header_component, body_component, footer_component, buttons_component].compact
  end

  private

  def header_component
    type = @t.header_type.to_s
    return if type.blank?

    type == 'text' ? header_text_component : header_media_component(type)
  end

  def header_text_component
    comp = { type: 'HEADER', format: 'TEXT', text: @t.header_content }
    sample = Array(samples['header']).first
    comp[:example] = { header_text: [sample] } if sample.present?
    comp
  end

  def header_media_component(type)
    # En creación Meta exige el handle del resumable upload (no una URL plana).
    handle = @t.header_handle.presence || @t.header_media_url
    { type: 'HEADER', format: type.upcase, example: { header_handle: [handle] } }
  end

  def body_component
    return if @t.body_text.blank?

    comp = { type: 'BODY', text: @t.body_text }
    body_samples = Array(samples['body']).compact
    comp[:example] = { body_text: [body_samples] } if body_samples.any? # array 2D
    comp
  end

  def footer_component
    return if @t.footer_text.blank?

    { type: 'FOOTER', text: @t.footer_text }
  end

  def buttons_component
    btns = Array(@t.buttons)
    return if btns.empty?

    { type: 'BUTTONS', buttons: btns.map { |b| create_button(b) } }
  end

  def create_button(button)
    b = indifferent(button)
    case b['type'].to_s.upcase
    when 'QUICK_REPLY'  then { type: 'QUICK_REPLY', text: b['text'] }
    when 'URL'          then url_button(b)
    when 'PHONE_NUMBER' then { type: 'PHONE_NUMBER', text: b['text'], phone_number: b['phone_number'] }
    when 'COPY_CODE'    then { type: 'COPY_CODE', example: Array(b['example']).compact.first }
    end
  end

  def url_button(b)
    comp = { type: 'URL', text: b['text'], url: b['url'] }
    example = Array(b['example']).reject { |v| v.to_s.blank? }
    comp[:example] = example if example.any?
    comp
  end

  def samples
    (@t.sample_values || {}).with_indifferent_access
  end

  def indifferent(hash)
    hash.respond_to?(:with_indifferent_access) ? hash.with_indifferent_access : hash
  end
end
