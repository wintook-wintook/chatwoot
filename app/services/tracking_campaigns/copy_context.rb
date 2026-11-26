# frozen_string_literal: true

# «Redactar con Dali» (TrackingCampaigns::CopyWriter) — LO QUE SABE de la campaña para escribir: la empresa y cómo habla,
# el tipo y su objetivo, el evento o la oferta, la ficha (lo mismo que sabe el vendedor), las preguntas autorizadas, las
# variables por contacto, los mensajes anteriores (para no repetirlos) y las ligas que se agregan solas.
class TrackingCampaigns::CopyContext
  GOALS = {
    'confirm' => 'que confirme aquí mismo si va',
    'external' => 'que lo haga por su cuenta con la liga y avise escribiendo «%<kw>s»',
    'done' => 'que lo haga y avise que ya lo hizo',
    'relay' => 'que diga que le interesa (lo atiende alguien del equipo)',
    'appointment' => 'que agende una cita',
    'answers' => 'que conteste la encuesta'
  }.freeze
  KINDS = { 'invite' => 'Invitar a un evento', 'offer' => 'Ofrecer un producto, servicio o promoción',
            'reactivate' => 'Reactivar a un cliente que hace tiempo no compra', 'renew' => 'Recordar un vencimiento o pago',
            'survey' => 'Encuesta de satisfacción' }.freeze
  VARIABLES = { 'reactivate' => %w[ultima_compra], 'renew' => %w[que_vence vence monto] }.freeze

  def initialize(campaign, params = {})
    @campaign = campaign
    @brief = campaign.brief.to_h
    @params = params
  end

  def text
    [company_lines, campaign_lines, function_lines, objection_lines, variable_line].flatten.compact_blank.join("\n")
  end

  VOICE = { 'tone' => 'Cómo habla la empresa', 'never' => 'Nunca', 'words' => 'Palabras propias o a evitar' }.freeze

  def company_lines
    voice = config&.voice.to_h
    ["- La empresa: #{@campaign.account.name}#{". #{voice['who']}" if voice['who'].present?}",
     config&.display_name.presence && "- Quien escribe se presenta como: #{config.display_name}",
     *VOICE.filter_map { |key, label| "- #{label}: #{voice[key]}" if voice[key].present? }]
  end

  def campaign_lines
    goal = TrackingCampaigns::CampaignKit.goal(kind, @brief['offer_goal'])
    ["- Tipo de campaña: #{KINDS.fetch(kind, kind)}",
     "- Lo que buscamos: #{format(GOALS.fetch(goal, GOALS['relay']), kw: keyword)}",
     @brief['offer_what'].present? && "- Qué: #{@brief['offer_what']}",
     event_line]
  end

  def event_line
    event = function&.event if kind == 'invite'
    return nil unless event

    when_text = Motor2::Skills::Appointments.label(event.starts_at.in_time_zone(config.zone))
    ["- El evento: «#{event.name}», #{when_text}", event.location.presence && "en #{event.location}",
     event.description.presence && "— #{event.description.to_s.squish.first(500)}"].compact.join(' ')
  end

  # La ficha (datos, productos con precio de promoción, vigencia): lo mismo que sabe el vendedor.
  def function_lines
    function&.facts_block.to_s.sub(/\ALA FICHA[^\n]*\n/, '')
  end

  def objection_lines
    rows = Array(@brief['objections']).filter_map do |o|
      "- «#{o['objection']}» → #{o['answer']}" if o.is_a?(Hash) && o['objection'].present?
    end
    rows.any? ? "Preguntas frecuentes (con su respuesta autorizada):\n#{rows.first(8).join("\n")}" : nil
  end

  def variable_line
    vars = %w[contacto] + VARIABLES.fetch(kind, [])
    "- Variables que puedes usar (se llenan solas por contacto; {{monto}} ya trae el signo $): #{vars.map { |v| "{{#{v}}}" }.join(', ')}"
  end

  # Lo que ya le llegó antes de ese mensaje: la apertura, los toques y, en correo, los correos anteriores.
  def previous(target, number)
    return numbered(email_bodies.first(number - 1), 'Correo').join("\n") if target == 'email'

    (opener_rows + numbered(Array(@brief['touch_texts']).first(number - 1), 'Toque')).join("\n")
  end

  def opener_rows
    [template_text(0) && "Apertura: #{template_text(0)}", @brief['opener'].presence && "Apertura (fijo): #{@brief['opener']}"].compact
  end

  def numbered(texts, label) = texts.each_with_index.filter_map { |t, i| "#{label} #{i + 1}: #{t.to_s.first(600)}" if t.present? }

  def email_bodies = Array(@campaign.touches.to_h['emails']).map { |e| e.to_h['body'] }

  def template_text(index)
    name = Array(@campaign.touches.to_h['templates'])[index].presence
    return nil unless name && @campaign.inbox&.whatsapp?

    body_of(Array(@campaign.inbox.channel.message_templates).find { |t| t['name'] == name })
  end

  def body_of(template) = Array(template.to_h['components']).find { |c| c['type'] == 'BODY' }&.dig('text')

  # ---------- de la campaña ----------

  def package_links = Array(@brief['links']).select { |l| l['use'] == 'package' && l['url'].present? }

  # Encuesta: sin botón a una liga (las preguntas y sus botones se agregan solos).
  def package_urls = kind == 'survey' ? [] : package_links.pluck('url')

  def links_note
    names = package_links.pluck('name').compact_blank
    return 'no hay liga de registro o compra.' if names.empty?

    "la liga (#{names.join(', ')}) se agrega sola al final; puedes decir «abajo te dejo la liga»."
  end

  def closing
    goal = TrackingCampaigns::CampaignKit.goal(kind, @brief['offer_goal'])
    return "pedirle que escriba *#{keyword}* cuando lo haga" if goal == 'external'
    return 'la pregunta de si va (que conteste aquí)' if goal == 'confirm'
    return 'la invitación a contestar (es un minuto)' if goal == 'answers'
    return 'la oferta de ayudarle a hacerlo ya (renovar o pagar)' if kind == 'renew'

    'una pregunta fácil de contestar que lo lleve al siguiente paso'
  end

  def kind = @brief['kind'].to_s

  def keyword = @brief['goal_keyword'].presence || TrackingCampaigns::CampaignKit.kit(kind)[:keyword]

  def usted? = config&.tone == 'usted'

  def config
    return @config if defined?(@config)

    agent = @campaign.tracking_template
    @config = agent && Motor2::Config.new(agent, answers: TrackingCampaigns::Motor2Brief.seller_answers(@campaign).except('content'))
  end

  def function = config&.function

  private :company_lines, :campaign_lines, :event_line, :function_lines, :objection_lines, :variable_line, :opener_rows,
          :numbered, :email_bodies, :template_text, :body_of, :package_links, :kind, :keyword, :config, :function
end
