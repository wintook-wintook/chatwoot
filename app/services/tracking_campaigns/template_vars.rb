# frozen_string_literal: true

# Campaña con Vendedor IA por WhatsApp — de dónde sale cada variable de la plantilla de cada toque:
#
#   touches['template_vars'] = { 'promo_noviembre' => { '1' => { 'source' => 'contact_first_name' },
#                                                       '2' => { 'source' => 'offer_what' },
#                                                       'fecha' => { 'source' => 'text', 'text' => '30 de noviembre' } } }
#
# Lo usa Motor2::CampaignTemplateVarsHook (Whatsapp::TemplateParamsProcessor) al mandar el toque, y «Simular». Si la
# plantilla no tiene su mapa, trae variables en el encabezado o falta un dato, se llena como siempre.
module TrackingCampaigns::TemplateVars
  SOURCES = %w[contact_first_name contact_name contact_company offer_what event_name event_date event_place
               last_purchase due_what due_date due_amount text].freeze
  VAR = /\{\{\s*([\w.]+)\s*\}\}/

  module_function

  def sanitize(raw)
    Motor2::Sanitizer.plain(raw).to_h.first(20).to_h do |name, vars|
      rules = Motor2::Sanitizer.plain(vars).to_h.first(20).to_h
      [name.to_s.first(200), rules.transform_keys { |var| var.to_s.first(60) }.transform_values { |r| rule(r) }]
    end
  end

  def rule(raw)
    raw = Motor2::Sanitizer.plain(raw)
    { 'source' => raw['source'].to_s.presence_in(SOURCES) || 'text', 'text' => raw['text'].to_s.first(200) }
  end

  def mapping(campaign, template_name) = campaign&.touches.to_h.dig('template_vars', template_name.to_s).to_h

  # Los parámetros para Meta (como TemplateParamsProcessor#success_result), o nil para llenarla como siempre.
  def parameters(campaign, contact, template)
    rules = mapping(campaign, template.to_h['name'])
    return nil if rules.empty? || header_variables?(template)

    vars = variables(template)
    values = vars.index_with { |var| value(campaign, contact, rules[var]) }
    return nil if vars.empty? || values.values.any?(&:blank?)

    { success: true, errors: [], parameters: build(vars, values) }
  end

  def variables(template)
    body = Array(template.to_h['components']).find { |c| c['type'] == 'BODY' }&.dig('text').to_s
    body.scan(VAR).flatten.uniq
  end

  def build(vars, values)
    return vars.sort_by(&:to_i).map { |var| { type: 'text', text: values[var].to_s } } if vars.all? { |v| v.match?(/\A\d+\z/) }

    builder = Whatsapp::PopulateTemplateParametersService.new
    vars.map { |var| builder.build_named_parameter(var, values[var]) }
  end

  def header_variables?(template)
    header = Array(template.to_h['components']).find { |c| c['type'] == 'HEADER' }
    header.present? && header['text'].to_s.match?(VAR)
  end

  def value(campaign, contact, rule)
    rule = rule.to_h
    case rule['source']
    when 'contact_first_name' then contact&.name.to_s.strip.split(/\s+/).first
    when 'contact_name' then contact&.name.to_s.strip
    when 'contact_company' then company(contact)
    when 'offer_what' then campaign.brief.to_h['offer_what'].to_s.squish.first(200)
    when 'event_name', 'event_date', 'event_place' then event_value(campaign, rule['source'])
    else other_value(contact, rule)
    end.presence
  end

  # Los datos de cada contacto (TrackingCampaigns::ContactFacts) o el texto fijo.
  def other_value(contact, rule)
    return rule['text'].to_s unless TrackingCampaigns::ContactFacts::KEYS.include?(rule['source'])

    contact ? TrackingCampaigns::ContactFacts.new(contact).values[rule['source']] : nil
  end

  def company(contact)
    attrs = contact&.additional_attributes || {}
    (attrs['company_name'].presence || attrs['company'].presence || contact.try(:organization)&.name).to_s.strip
  end

  def event_value(campaign, source)
    event = campaign.event || campaign.account.events.find_by(id: campaign.brief.to_h['event_id'])
    return nil unless event
    return event.name if source == 'event_name'
    return event.location if source == 'event_place'

    Motor2::Skills::Appointments.label(event.starts_at.in_time_zone(campaign.inbox&.timezone.presence || 'America/Mexico_City'))
  end
end
