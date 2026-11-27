# frozen_string_literal: true

# Campaña con Vendedor IA — «Redactar con Dali»: escribe los textos de la campaña con TODO lo que ya tiene (tipo y
# objetivo, el evento o la oferta, la ficha, las preguntas autorizadas, las ligas y cómo habla la empresa).
#
#   target   info    la información completa de WhatsApp: copy con gancho, emojis con medida, viñetas, *negritas*
#            touch   el mensaje fijo del toque N: otro ángulo, más corto
#            reminder  Invitar: el mensaje fijo de un recordatorio del evento (kind: day_before|hour_before, pending)
#            email   el correo N (1 = el que lleva todo; los demás, seguimiento): asunto, asunto B y bloques
#   number   el toque o el correo (touch: 1 = toque 1; email: 1 = primer correo)
#   tone     cercano | profesional | entusiasta      length  corto | completo
#   instruction  lo que pide («más corto», «resalta que es gratis»)    current  el texto de ahora, para mejorarlo
#
#   TrackingCampaigns::CopyWriter.new(campaign, target: 'info', tone: 'cercano').call
#   → { text: '…' } · email: { subject:, subject_b:, blocks: [{ type:, text:, url: }] } · { error: '…' }
# Las ligas «con la información» se agregan solas al final (Skills::CampaignNotes#with_package_links): no las escribe.
class TrackingCampaigns::CopyWriter < Cases::Ai::BaseService
  TARGETS = %w[info touch email].freeze
  TONES = { 'cercano' => 'cercano y cálido', 'profesional' => 'profesional y claro', 'entusiasta' => 'entusiasta, con energía' }.freeze

  def initialize(campaign, params = {})
    super(account: campaign.account)
    @campaign = campaign
    @params = params.to_h.stringify_keys
  end

  def call
    return reminder if target == 'reminder'
    return { error: 'Elige qué quieres redactar.' } unless TARGETS.include?(target)
    return { error: 'La cuenta no tiene OpenAI conectado.' } unless available?

    result = chat(system: system_prompt, user: user_prompt, json: true, temperature: 0.8, max_tokens: email? ? 1400 : 900)
    result.is_a?(Hash) ? shape(result) : { error: 'Dali no pudo redactarlo; intenta de nuevo.' }
  end

  private

  def model = AiModels::DALI

  # Invitar: el mensaje fijo de un recordatorio del evento (kind, pending), con sus variables.
  def reminder
    TrackingCampaigns::ReminderWriter.new(@campaign, kind: @params['kind'], pending: @params['pending'])
                                     .draft(tone: TONES[@params['tone'].to_s], instruction: @params['instruction'], current: @params['current'])
  end

  def target = @params['target'].to_s

  def number = [@params['number'].to_i, 1].max

  def email? = target == 'email'

  # ---------- la respuesta ----------

  def shape(result)
    return email_shape(result) if email?

    text = whatsapp_format(result['texto'].to_s.strip).gsub('${{monto}}', '{{monto}}')
    text = text.gsub(/[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}]\s?/, '') if no_emojis?
    text.present? ? { text: text.first(TrackingCampaigns::Motor2Brief::MAX_CONTENT) } : { error: 'Dali no pudo redactarlo; intenta de nuevo.' }
  end

  # WhatsApp: negritas con UN asterisco (el modelo a veces pone **así**) y sin títulos de markdown.
  def whatsapp_format(text) = text.gsub(/\*\*(.+?)\*\*/, '*\\1*').gsub(/^\#{1,6}\s*/, '')

  def email_shape(result)
    blocks = Array(result['bloques']).filter_map { |b| block(b.to_h) }
    return { error: 'Dali no pudo redactarlo; intenta de nuevo.' } if blocks.empty?

    { subject: result['asunto'].to_s.strip.first(150), subject_b: result['asunto_b'].to_s.strip.first(150), blocks: blocks }
  end

  BLOCK_TYPES = { 'titulo' => 'heading', 'texto' => 'text', 'boton' => 'button' }.freeze

  def block(raw)
    type = BLOCK_TYPES[raw['tipo'].to_s]
    text = raw['texto'].to_s.strip.gsub('${{monto}}', '{{monto}}')
    return nil if type.nil? || text.blank?

    url = raw['url'].to_s.strip
    return nil if type == 'button' && ctx.package_urls.exclude?(url) # solo ligas de la campaña (no inventa)

    { type: type, text: text, url: type == 'button' ? url : '' }
  end

  # ---------- lo que se le pide ----------

  def system_prompt
    <<~TEXT
      Eres Dali, redactora de campañas para empresas en México. Escribes en español de México, natural y sin
      frases de plantilla («¡No te lo pierdas!» solo si de verdad aplica). Nunca inventas datos: fechas, precios,
      lugares, cupos o beneficios salen SOLO de LO QUE SABES; si algo no está, no lo menciones. Sin relleno
      («espero que estés bien», «espero que te encuentres de maravilla»): ve directo a lo que importa.
      Trata al contacto de #{ctx.usted? ? 'usted' : 'tú'}. Tono: #{TONES.fetch(@params['tone'].to_s, TONES['cercano'])}.
      #{target_rules}#{request_rule}
    TEXT
  end

  def no_emojis? = @params['instruction'].to_s.match?(/sin\s+emoj/i)

  def emoji_rule
    return 'SIN emojis.' if no_emojis?

    "Emojis con medida (#{short? ? '3 a 5' : '4 a 8'}), al inicio de renglón o para marcar datos (📅 📍 ⏰ ✅ 🎁 💰)."
  end

  # Lo que pidió manda sobre las reglas de formato («sin emojis», «más corto»…).
  def request_rule
    return '' if @params['instruction'].blank?

    "\nIMPORTANTE — lo que pidió quien redacta MANDA sobre las reglas de arriba: #{@params['instruction'].to_s.squish.first(300)}"
  end

  def target_rules
    case target
    when 'info' then info_rules
    when 'touch' then touch_rules
    else email_rules
    end
  end

  def info_rules
    <<~TEXT
      Escribes LA INFORMACIÓN COMPLETA que se manda por WhatsApp cuando el contacto pide saber más.
      - Primera línea: un gancho corto que dé ganas de leer.
      - #{emoji_rule}
      - Datos en renglones cortos o viñetas (• o ✅). Resalta lo clave con *asteriscos* (negritas de WhatsApp).
      - Sin títulos con #, sin [ligas](url) y sin escribir URLs: #{ctx.links_note}
      - Cierra con #{ctx.closing}.
      - #{short? ? 'Corto: máximo 600 caracteres.' : 'Completo pero escaneable: máximo 1,200 caracteres.'}
      Responde solo JSON: {"texto": "..."}
    TEXT
  end

  def touch_rules
    <<~TEXT
      Escribes el TOQUE #{number}: un recordatorio de WhatsApp a quien NO ha contestado. 1 o 2 renglones, máximo 220
      caracteres, con OTRO ángulo que los mensajes anteriores (no los repitas), amable y sin presionar, que termine
      con una pregunta fácil. No empieces igual que los mensajes anteriores. Puedes usar {{contacto}}. 1 emoji como
      mucho. Sin URLs.
      #{Motor2::CampaignPersuasion.angle(number + 1, total_messages, kind)}.
      Responde solo JSON: {"texto": "..."}
    TEXT
  end

  def email_rules
    <<~TEXT
      Escribes el #{number == 1 ? 'PRIMER CORREO: el que lleva toda la información' : "CORREO #{number}: un seguimiento a quien no contestó, más corto y con otro ángulo"}.
      - Asunto: corto (máximo 60 caracteres), concreto, sin MAYÚSCULAS ni signos de más; puede llevar {{contacto}}.
        Asunto B: otra forma de decirlo para una prueba A/B.
      - Cuerpo en bloques: «titulo» (opcional, uno), «texto» (párrafos cortos; empieza con un saludo con {{contacto}}),
        «boton» (texto del botón y su url: SOLO una de estas ligas: #{ctx.package_urls.presence&.join(', ') || 'no hay; no pongas botón'}).
      - #{email_length} Cierra con #{ctx.closing}.
      - Sin firma ni despedida con nombre (se agrega sola). Emojis: ninguno o 1.#{survey_email_note}
      Responde solo JSON: {"asunto": "...", "asunto_b": "...", "bloques": [{"tipo": "titulo|texto|boton", "texto": "...", "url": "..."}]}
    TEXT
  end

  def email_length
    return '1 o 2 párrafos.' if number > 1

    short? ? 'Corto: 2 a 3 párrafos.' : '3 a 5 párrafos cortos.'
  end

  def survey_email_note
    @campaign.brief.to_h['kind'] == 'survey' ? "\n- Es una encuesta: invita a contestarla; las preguntas y sus botones se agregan solos debajo." : ''
  end

  def user_prompt
    parts = ["LO QUE SABES:\n#{ctx.text}"]
    previous = ctx.previous(target, number) if %w[touch email].include?(target)
    parts << "MENSAJES ANTERIORES (no los repitas):\n#{previous}" if previous.present?
    parts << "EL TEXTO DE AHORA (mejóralo; conserva lo que esté bien):\n#{@params['current'].to_s.first(4000)}" if @params['current'].present?
    parts << "LO QUE PIDE: #{@params['instruction'].to_s.squish.first(300)}" if @params['instruction'].present?
    parts.join("\n\n")
  end

  def ctx = @ctx ||= TrackingCampaigns::CopyContext.new(@campaign, @params)

  def kind = @campaign.brief.to_h['kind'].to_s

  def total_messages = [@campaign.touches.to_h['attempts'].to_i, number + 1].max

  def short? = @params['length'].to_s == 'corto' || target == 'touch'
end
