# frozen_string_literal: true

# Campaña con IA (Motor 2.0) — lo que trae cada tipo de campaña de fábrica (y se puede cambiar en la campaña):
#
#   goals     qué cuenta como logrado (el primero es el de inicio):
#               confirm   confirma que va al evento (Eventos: confirmó)
#               external  lo hace afuera (registro en Zoom, compra en línea, pago) y lo avisa con la palabra clave
#               done      confirma que ya lo hizo (pagó, renovó)
#               relay     le interesa → pasa a quien sigue (agente o persona)
#               appointment  le interesa → agenda la cita
#               answers   contesta la encuesta
#   facts     los campos de la ficha (lo que sabe la IA); 'more' es texto libre
#   replies   las respuestas fijas: achieved (lo logró), not_now (no esta vez: pide permiso para la próxima),
#             future_yes (acepta la próxima), opt_out (no quiere que le escriban de esto)
#   labels    las etiquetas que le quedan al CONTACTO: achieved, future_yes, opt_out. Al que tiene la de opt_out
#             no lo vuelve a inscribir otra campaña del mismo tipo (TrackingCampaigns::Enroll).
#   keyword   la palabra clave de inicio para «external»
module TrackingCampaigns::CampaignKit
  KINDS = %w[offer invite reactivate renew survey].freeze
  GOALS = %w[confirm external done relay appointment answers].freeze
  REPLY_KEYS = %w[achieved not_now future_yes opt_out low].freeze
  LABEL_KEYS = %w[achieved future_yes opt_out].freeze
  LINK_USES = %w[package request problem].freeze
  MAX_LINKS = 6
  MAX_FACT = 800

  FACT_LABELS = TrackingCampaigns::CampaignKitData::FACT_LABELS
  KIT = TrackingCampaigns::CampaignKitData::KIT

  # La etiqueta de «lo logró» de inicio, según el objetivo.
  ACHIEVED_LABELS = { 'confirm' => 'confirmo-asistencia', 'external' => 'registrado', 'done' => 'renovo', 'relay' => 'le-interesa',
                      'appointment' => 'cita', 'answers' => 'encuesta-contestada' }.freeze
  EXTERNAL_LABELS = { 'invite' => 'registrado', 'offer' => 'compro', 'reactivate' => 'reactivado', 'renew' => 'pagado' }.freeze

  module_function

  def kit(kind) = KIT[kind.to_s] || KIT['offer']

  def goals(kind) = kit(kind)[:goals]

  def goal(kind, raw) = raw.to_s.presence_in(goals(kind)) || goals(kind).first

  def facts(kind) = kit(kind)[:facts]

  # Con «external»: la palabra con la que avisa que ya lo hizo.
  def keyword(raw, goal) = goal == 'external' ? raw['goal_keyword'].to_s.squish.first(40).presence : nil

  # ¿Pregunta si puede escribirle la próxima vez? (Invitar, Ofrecer y Reactivar).
  def asks_future?(kind) = kit(kind)[:replies]['not_now'].present?

  def default_replies(kind) = kit(kind)[:replies]

  def default_labels(kind, goal)
    achieved = goal == 'external' ? EXTERNAL_LABELS[kind.to_s] : ACHIEVED_LABELS[goal.to_s]
    { 'achieved' => achieved.to_s }.merge(kit(kind)[:labels])
  end

  # La ficha, sus ligas, las respuestas fijas y las etiquetas (TrackingCampaigns::Motor2Brief#brief).
  def sanitize(kind, raw)
    { 'facts' => sanitize_facts(kind, raw['facts']), 'links' => sanitize_links(raw['links']),
      'replies' => sanitize_replies(raw['replies']), 'labels' => raw['labels'].is_a?(Hash) ? sanitize_labels(raw['labels']) : nil,
      'reminders' => (TrackingCampaigns::EventReminders.sanitize(raw['reminders']) if kind == 'invite'),
      'last_call' => (TrackingCampaigns::LastCall.sanitize(raw['last_call']) if TrackingCampaigns::LastCall::KINDS.include?(kind)) }
      .merge(offer_products(kind, raw), survey_parts(kind, raw), renew_parts(kind, raw))
  end

  # Recordar: de qué contratos y en qué días antes de vencer (TrackingCampaigns::RenewEnroll).
  def renew_parts(kind, raw)
    return {} unless kind == 'renew' && raw['renew_source'].present?

    { 'renew_source' => TrackingCampaigns::RenewEnroll.sanitize(raw['renew_source']) }
  end

  # Encuesta: las preguntas con tipo (y el texto que se pregunta) y a quién le llega el caso por calificación baja.
  def survey_parts(kind, raw)
    return {} unless kind == 'survey'

    items = TrackingCampaigns::SurveyItems.sanitize(raw['survey_items'])
    parts = { 'low_case' => TrackingCampaigns::SurveyItems.low_case(raw['low_case']).presence }
    return parts.compact if items.empty?

    parts.merge('survey_items' => items, 'survey_questions' => TrackingCampaigns::SurveyItems.questions(items)).compact
  end

  # Ofrecer y Reactivar: los productos del Catálogo con su precio de promoción y la vigencia (TrackingCampaigns::OfferProducts).
  def offer_products(kind, raw)
    return {} unless %w[offer reactivate].include?(kind)

    { 'products' => TrackingCampaigns::OfferProducts.sanitize(raw['products']).presence,
      'valid_until' => TrackingCampaigns::OfferProducts.valid_until(raw['valid_until']) }
  end

  # Lo que guarda la campaña: los campos de su tipo; lo vacío se queda vacío (gana lo de fábrica al usarlo).
  def sanitize_facts(kind, raw)
    raw = Motor2::Sanitizer.plain(raw)
    facts(kind).index_with { |k| raw[k].to_s.strip.first(k == 'more' ? TrackingCampaigns::Motor2Brief::MAX_TEXT : MAX_FACT) }
               .compact_blank
  end

  def sanitize_links(raw)
    Array(raw).first(MAX_LINKS).filter_map do |l|
      l = Motor2::Sanitizer.plain(l)
      url = l['url'].to_s.strip.first(2000)
      next unless url.match?(%r{\Ahttps?://\S+\z})

      { 'name' => l['name'].to_s.squish.first(60).presence || 'Liga', 'url' => url,
        'use' => l['use'].to_s.presence_in(LINK_USES) || 'package', 'note' => l['note'].to_s.squish.first(200) }.compact_blank
    end
  end

  def sanitize_replies(raw)
    raw = Motor2::Sanitizer.plain(raw)
    REPLY_KEYS.index_with { |k| raw[k].to_s.strip.first(600) }.compact_blank
  end

  # Etiquetas de contacto: minúsculas, sin espacios (como las de la cuenta: Label).
  def sanitize_labels(raw)
    raw = Motor2::Sanitizer.plain(raw)
    LABEL_KEYS.index_with { |k| label_title(raw[k]) }
  end

  def label_title(value)
    value.to_s.downcase.strip.gsub(/\s+/, '-').gsub(/[^\p{L}\p{N}_-]/, '').first(50)
  end

  # Lo que tiene la campaña o, si lo dejó vacío, lo de fábrica.
  def reply(brief, key)
    brief = brief.to_h
    brief.dig('replies', key).presence || default_replies(brief['kind'])[key].to_s
  end

  # Las etiquetas se guardan siempre (la pantalla las trae llenas): una vacía es «sin etiqueta».
  def label(brief, key)
    brief = brief.to_h
    saved = brief['labels']
    return saved[key].to_s if saved.is_a?(Hash) && saved.key?(key)

    default_labels(brief['kind'], goal(brief['kind'], brief['offer_goal']))[key].to_s
  end

  # Para la pantalla: lo de fábrica de cada tipo.
  def options
    KIT.to_h do |kind, data|
      [kind, { goals: data[:goals], facts: data[:facts], keyword: data[:keyword], replies: data[:replies],
               labels: data[:goals].index_with { |g| default_labels(kind, g) }, asks_future: asks_future?(kind) }]
    end
  end
end
