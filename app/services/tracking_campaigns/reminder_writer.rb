# frozen_string_literal: true

# Campaña con IA · Invitar — los recordatorios del evento escritos por la IA, en dos momentos:
#   al momento (TrackingCampaigns::EventReminders, con la ventana abierta y «La IA lo escribe al momento»): para ESE
#     contacto, con sus datos reales y lo último de su plática. Si la IA falla, nil (sale el texto fijo).
#   el mensaje fijo («Redactar con Dali» en «Recordatorios del evento»): con las variables {{nombre}} {{evento}}
#     {{cuando}} {{lugar}} {{liga}}, para que sirva a todos.
# A los que confirmaron: un recordatorio cálido con lo práctico. A los que no han contestado: la última invitación,
# persuasiva con la urgencia real (mañana, en una hora) y una salida fácil.
#
#   TrackingCampaigns::ReminderWriter.new(campaign, kind: 'day_before', pending: true).draft(tone: 'cercano')  → { text: }
#   TrackingCampaigns::ReminderWriter.new(campaign, kind: 'hour_before', pending: false).for_contact(tracking, values) → '…'
class TrackingCampaigns::ReminderWriter < Cases::Ai::BaseService
  WHEN = { 'day_before' => 'mañana', 'hour_before' => 'en una hora', 'last_call' => 'mañana o hoy',
           'appointment' => 'pronto ({{cuando}})' }.freeze
  VARIABLES_RULE = 'Es un texto para TODOS: para el nombre usa {{nombre}} y para la liga {{liga}} (se llenan solas por ' \
                   'contacto); también puedes usar {{evento}} {{cuando}} {{lugar}} (Invitar), {{oferta}} {{cuando}} (promoción) o ' \
                   '{{cuando}} {{con}} (la cita: día y hora, y con quién).'

  def initialize(campaign, kind:, pending:)
    super(account: campaign.account)
    @campaign = campaign
    @kind = kind.to_s.presence_in(WHEN.keys) || 'day_before'
    @pending = ActiveModel::Type::Boolean.new.cast(pending) || false
  end

  # El mensaje fijo, con variables.
  def draft(tone: nil, instruction: nil, current: nil)
    return { error: 'La cuenta no tiene OpenAI conectado.' } unless available?

    user = [context, current.present? && "EL TEXTO DE AHORA (mejóralo):\n#{current.to_s.first(600)}",
            instruction.present? && "LO QUE PIDE (manda sobre las reglas): #{instruction.to_s.squish.first(300)}"]
    text = write(rules(VARIABLES_RULE, tone), user)&.gsub(/\{\{\s*contacto\s*\}\}/, '{{nombre}}')
    return { error: 'Dali no pudo redactarlo; intenta de nuevo.' } unless text

    { text: with_link?(text) ? "#{text} {{liga}}" : text }
  end

  # Para ese contacto, con sus datos reales y lo último que platicó. nil si falla.
  def for_contact(tracking, values)
    return nil unless available?

    data = values.compact_blank.map { |k, v| "- #{k}: #{v}" }.join("\n")
    text = write(rules('Escribe para ESTE contacto con sus datos reales; si escribió algo hace poco, retómalo en una frase.'),
                 [context, "SUS DATOS:\n#{data}", conversation(tracking)])
    return nil if text.blank?

    link = values['liga'].to_s
    link.present? && text.exclude?(link) ? "#{text}\n#{link}" : text
  end

  private

  def model = AiModels::AGENTS

  def write(system, user)
    result = chat(system: system, user: user.compact_blank.join("\n\n"), json: true, temperature: 0.7, max_tokens: 300)
    result.is_a?(Hash) ? result['texto'].to_s.strip.gsub(/\*\*(.+?)\*\*/, '*\1*').first(600).presence : nil
  end

  def rules(extra, tone = nil)
    <<~TEXT
      #{subject}
      #{@pending ? pending_rule : confirmed_rule}
      Corto: 1 a 3 renglones, máximo 300 caracteres, 1 o 2 emojis como mucho, sin relleno («espero que estés bien»).
      #{includes} Nunca inventes datos.
      Tono: #{tone.presence || 'cercano'}. #{extra}
      Responde solo JSON: {"texto": "..."}
    TEXT
  end

  # Ofrecer y Reactivar: el «Último aviso» de la promoción (TrackingCampaigns::LastCall); Invitar: el recordatorio del evento.
  def subject
    return 'Escribes por WhatsApp el ÚLTIMO AVISO de una promoción que termina pronto ({{cuando}}), en español de México.' if last_call?
    return 'Escribes por WhatsApp el recordatorio de la cita que agendó por esta promoción, en español de México.' if appointment?

    "Escribes por WhatsApp el recordatorio de un evento que es #{WHEN[@kind]}, en español de México."
  end

  def includes
    return 'Incluye qué es la promoción ({{oferta}}) y cuándo termina ({{cuando}}).' if last_call?
    return 'Incluye día y hora ({{cuando}}) y con quién ({{con}}), y pídele que confirme que sí llega.' if appointment?

    "Incluye cuándo es#{@kind == 'hour_before' ? ' y la liga para entrar' : ' y dónde'}."
  end

  def last_call? = @kind == 'last_call'

  def appointment? = @kind == 'appointment'

  # La liga va en la última invitación y una hora antes (para entrar): si no la puso, al final.
  def with_link?(text) = (@pending || @kind == 'hour_before') && text.exclude?('{{liga}}')

  def confirmed_rule
    return 'Ya agendó su cita: recuérdasela con calidez y lo práctico (lo que sabes de la promoción, si sirve).' if appointment?

    'Ya confirmó que va (o ya se registró): recuérdaselo con calidez y lo práctico; no le vuelvas a preguntar si va ni le ' \
      'pidas registrarse o la palabra clave.'
  end

  def pending_rule
    what = last_call? ? 'la oferta: es el ÚLTIMO aviso antes de que termine la promoción' : 'la invitación: es la ÚLTIMA invitación'
    "No ha contestado #{what}. Persuasiva con la urgencia real (#{WHEN[@kind]}) y UN beneficio concreto de LO QUE SABES; " \
      'termina con una pregunta fácil o una salida amable.'
  end

  def context = "LO QUE SABES:\n#{TrackingCampaigns::CopyContext.new(@campaign).text}"

  def conversation(tracking)
    return nil unless tracking.conversation

    rows = tracking.conversation.messages.where(message_type: %w[incoming outgoing], private: false)
                   .order(created_at: :desc).limit(6).reverse
                   .map { |m| "#{m.incoming? ? 'Contacto' : 'Nosotros'}: #{m.content.to_s.squish.first(200)}" }
    rows.any? ? "LO ÚLTIMO DE LA PLÁTICA:\n#{rows.join("\n")}" : nil
  end
end
