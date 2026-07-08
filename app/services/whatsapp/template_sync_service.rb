# frozen_string_literal: true

# @waba_templates
# Sincroniza las plantillas de Meta a la tabla `whatsapp_templates` con UPSERT POR FILA
# (parsea los components inversos), en vez de reemplazar el JSONB. No borra locales sin
# contraparte remota (drafts/local-only se conservan). Mantiene además el volcado al JSONB
# `message_templates` por compatibilidad con el picker de envío existente.
class Whatsapp::TemplateSyncService
  Result = Struct.new(:synced, :created, :updated, keyword_init: true)

  def initialize(channel)
    @channel = channel
    @account = channel.account
  end

  # source:
  #   :remote → jala fresco de Meta (llamada a la API) y actualiza el JSONB de compat.
  #   :cache  → usa lo que el canal YA tiene en message_templates (Chatwoot lo sincroniza
  #             solo); instantáneo y sin pegarle a Meta. Se usa al abrir el dashboard.
  def perform(source: :remote)
    remote = fetch_templates(source)
    created = 0
    updated = 0

    remote.each do |raw|
      attrs = parse(raw)
      next if attrs[:name].blank? || attrs[:language].blank?

      record = @channel.whatsapp_templates.find_or_initialize_by(name: attrs[:name], language: attrs[:language])
      record.new_record? ? created += 1 : updated += 1
      record.account = @account
      record.assign_attributes(attrs)
      # Meta ya validó; guardamos sin validar para no rechazar variantes existentes.
      record.save!(validate: false)
    rescue StandardError => e
      Rails.logger.warn "[waba_templates] sync: no se pudo upsertar #{attrs[:name]}/#{attrs[:language]}: #{e.message}"
    end

    # Solo al jalar fresco de Meta actualizamos el JSONB (en :cache ya es la fuente).
    @channel.update(message_templates: remote, message_templates_last_updated: Time.now.utc) if source == :remote && remote.present?

    Result.new(synced: remote.size, created: created, updated: updated)
  end

  private

  def fetch_templates(source)
    return Array(@channel.message_templates) if source == :cache

    Array(@channel.provider_service.templates_list)
  end

  def parse(raw)
    r = raw.with_indifferent_access
    components = Array(r[:components])
    header = component(components, 'HEADER')
    body   = component(components, 'BODY')
    footer = component(components, 'FOOTER')
    buttons = component(components, 'BUTTONS')

    {
      name: r[:name],
      language: r[:language],
      category: r[:category],
      status: r[:status].to_s.upcase.presence,
      meta_template_id: r[:id],
      quality_score: quality(r),
      rejection_reason: rejection(r)
    }.merge(header_attrs(header)).merge(
      body_text: body&.dig(:text),
      footer_text: footer&.dig(:text),
      buttons: parse_buttons(buttons),
      sample_values: parse_samples(header, body)
    )
  end

  def component(components, type)
    components.find { |c| c[:type].to_s.upcase == type }
  end

  # No sobreescribimos header_media_url/header_handle: la lista de Meta no los trae.
  def header_attrs(header)
    return { header_type: nil, header_content: nil } if header.nil?

    format = header[:format].to_s.upcase
    return { header_type: 'text', header_content: header[:text] } if format == 'TEXT'

    { header_type: format.downcase, header_content: nil }
  end

  def parse_buttons(buttons)
    return [] if buttons.nil?

    Array(buttons[:buttons]).map do |btn|
      b = btn.with_indifferent_access
      { 'type' => b[:type].to_s.upcase, 'text' => b[:text], 'url' => b[:url],
        'phone_number' => b[:phone_number], 'example' => b[:example] }.compact
    end
  end

  def parse_samples(header, body)
    samples = {}
    body_example = body&.dig(:example, :body_text)
    samples['body'] = Array(body_example).first if body_example.present? # 2D → primera fila
    header_example = header&.dig(:example, :header_text)
    samples['header'] = Array(header_example) if header_example.present?
    samples
  end

  def quality(r)
    score = (r.dig(:quality_score, :score) || r[:quality_score]).to_s.upcase
    WhatsappTemplate::QUALITY_SCORES.include?(score) ? score : nil
  end

  def rejection(r)
    reason = r[:rejected_reason].to_s
    reason.blank? || reason.casecmp('NONE').zero? ? nil : reason
  end
end
