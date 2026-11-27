# frozen_string_literal: true

# Campaña con IA · Invitar — cómo se configuran los recordatorios del evento (brief['reminders']) y qué dice la
# revisión antes de lanzar. Los manda TrackingCampaigns::EventReminders.
#
#   day_before / hour_before          prendido o apagado
#   day_who / hour_who                'confirmed' (solo los que confirmaron) | 'pending' (confirmados y los que no
#                                     han contestado). De fábrica: un día antes a los dos grupos; una hora antes,
#                                     solo a los confirmados.
#   day_text / hour_text              texto para los que confirmaron
#   day_pending_text / hour_pending_text   texto para los que no han contestado (última invitación)
#   day_ai / hour_ai / day_pending_ai / hour_pending_ai   con la ventana abierta, lo escribe la IA al momento para
#                                     cada contacto (TrackingCampaigns::ReminderWriter); de fábrica, sí. En false, el texto.
#   template / pending_template       plantillas de WhatsApp (pasadas 24 h); sin la segunda, se usa la primera
# Textos con {{nombre}} {{evento}} {{cuando}} {{lugar}} {{liga}}; vacíos = los de fábrica (DEFAULTS).
module TrackingCampaigns::EventReminderSettings
  KINDS = %w[day_before hour_before].freeze
  WHO = %w[confirmed pending].freeze
  DEFAULT_WHO = { 'day_before' => 'pending', 'hour_before' => 'confirmed' }.freeze
  PREFIX = { 'day_before' => 'day', 'hour_before' => 'hour' }.freeze
  DEFAULTS = {
    'day_before' => '¡Hola {{nombre}}! 😊 Te recordamos que mañana es {{evento}}: {{cuando}}. {{lugar}} ¡Te esperamos!',
    'hour_before' => '¡Hola {{nombre}}! En una hora empieza {{evento}}. {{liga}} ¡Nos vemos!',
    'day_before_pending' => '¡Hola {{nombre}}! Mañana es {{evento}}: {{cuando}}. ¿Te apartamos tu lugar? {{liga}}',
    'hour_before_pending' => '¡Hola {{nombre}}! En una hora empieza {{evento}}. ¿Te animas? {{liga}}'
  }.freeze
  LABELS = { 'day_before' => 'un día antes', 'hour_before' => 'una hora antes' }.freeze
  MAX_TEXT = 600
  BOOL = ActiveModel::Type::Boolean.new
  AI_KEYS = %w[ai pending_ai].freeze

  module_function

  def sanitize(raw)
    raw = raw.is_a?(Hash) ? raw.stringify_keys : {}
    KINDS.each_with_object(templates(raw)) do |kind, out|
      prefix = PREFIX[kind]
      out[kind] = flag(raw, kind)
      out["#{prefix}_who"] = raw["#{prefix}_who"].to_s.presence_in(WHO) || DEFAULT_WHO[kind]
      out.merge!(texts(raw, prefix))
    end
  end

  # Los textos de un recordatorio (confirmados y los que no han contestado) y si los escribe la IA al momento.
  def texts(raw, prefix)
    out = %w[text pending_text].to_h { |key| ["#{prefix}_#{key}", raw["#{prefix}_#{key}"].to_s.strip.first(MAX_TEXT)] }
    AI_KEYS.each_with_object(out) { |key, all| all["#{prefix}_#{key}"] = flag(raw, "#{prefix}_#{key}") }
  end

  # Sin la llave, de fábrica sí.
  def flag(raw, key) = raw.key?(key) ? BOOL.cast(raw[key]) || false : true

  def templates(raw)
    { 'template' => raw['template'].to_s.strip.first(200), 'pending_template' => raw['pending_template'].to_s.strip.first(200) }
  end

  # El texto (propio o de fábrica) para ese recordatorio y ese grupo.
  def text_for(config, kind, pending)
    key = "#{PREFIX[kind]}_#{pending ? 'pending_text' : 'text'}"
    config[key].presence || DEFAULTS[pending ? "#{kind}_pending" : kind]
  end

  # ¿Lo escribe la IA al momento (con la ventana abierta)?
  def ai?(config, kind, pending) = config["#{PREFIX[kind]}_#{pending ? 'pending_ai' : 'ai'}"] != false

  def template_for(config, pending)
    (pending && config['pending_template'].presence) || config['template'].presence
  end

  def pending_on?(config, kind) = config[kind] && config["#{PREFIX[kind]}_who"] == 'pending'

  # Para la revisión antes de lanzar: [nivel, texto]. En WhatsApp, pasadas 24 h solo salen con plantilla (Meta cobra).
  def check(campaign)
    config = sanitize(campaign.brief.to_h['reminders'])
    on = KINDS.select { |kind| config[kind] }
    return ['warning', 'Sin recordatorios: a los que confirmen no les llega nada antes del evento.'] if on.empty?
    if campaign.inbox&.whatsapp? && config['template'].blank?
      return ['warning', 'Recordatorios sin plantilla: a quien no haya escrito en 24 h no le llegarán. Elige una en «Mensajes».']
    end

    ['ok', summary(campaign, config, on)]
  end

  def summary(campaign, config, on)
    parts = on.map { |kind| "#{LABELS[kind]} (#{pending_on?(config, kind) ? 'confirmados y los que no han contestado' : 'solo confirmados'})" }
    text = "Recordatorios: #{parts.join(' y ')}."
    return text unless campaign.inbox&.whatsapp? && on.any? { |kind| pending_on?(config, kind) }

    "#{text} A los que no han contestado les llega#{reach(campaign)} con plantilla: Meta cobra cada una como mensaje de marketing."
  end

  def reach(campaign)
    size = Array(campaign.audience.to_h['contact_ids']).size
    size.positive? ? " hasta a #{size} invitados" : ''
  end
end
