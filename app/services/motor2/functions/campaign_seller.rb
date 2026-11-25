# frozen_string_literal: true

# Función «Vendedor de campaña» (Plan-Motor-Agentes §11.16): toca la puerta. La campaña manda el primer
# mensaje (plantilla del agente) y el agente sigue cuando contesta: despierta el interés en la oferta,
# resuelve 2–3 dudas y pasa el relevo (Motor2::Relay) a quien sigue. Lo que contestó en su asistente
# (motor2['answers']):
#
#   purpose          invite | offer | reactivate | renew | survey (para qué es la campaña)
#   offer_what       qué ofrece (o a qué invita) · facts: la ficha · links: las ligas con su uso
#   offer_goal       qué cuenta como logrado (TrackingCampaigns::CampaignKit::GOALS) · goal_keyword
#   replies / labels respuestas fijas y etiquetas del contacto (TrackingCampaigns::CampaignKit)
#   event_id         Invitar: el evento de Eventos (fecha, lugar, liga salen de ahí)
#   survey_questions Encuesta: hasta 3 preguntas, tal cual · low_score: menor a esto (0–10) es «baja»
#   relay            agent (al agente de la bandeja: prospectos o clientes) | person · user_id / team_id
#   objections       [{ objection, answer }] · tone · business_* · price_source
#   appointment_user_ids / appointment_minutes (con offer_goal = appointment)
#
# La oferta vive en el agente por ahora; la pantalla de campañas podrá mandar la suya (brief) después.
class Motor2::Functions::CampaignSeller
  include Motor2::Functions::ProspectPrices
  include Motor2::Functions::Extras

  KEY = 'campaign_seller'
  PURPOSES = %w[invite offer reactivate renew survey].freeze
  TEXTS = %w[tone purpose offer_what offer_details offer_goal relay price_source business_what business_who
             business_coverage business_why business_practical].freeze
  CHOICES = { 'purpose' => PURPOSES, 'offer_goal' => TrackingCampaigns::CampaignKit::GOALS, 'relay' => %w[agent person] }.freeze
  MAX_QUESTIONS = 3
  LOW_SCORE = 7
  BUSINESS = Motor2::Functions::Prospects::BUSINESS
  TONES = Motor2::Functions::Prospects::TONES
  PURPOSE_TEXT = {
    'invite' => 'INVITAR a un evento.',
    'offer' => 'OFRECER algo (producto, servicio o promoción).',
    'reactivate' => 'REACTIVAR a un cliente que hace tiempo no compra: que vuelva.',
    'renew' => 'RECORDAR algo que le toca (vencimiento, pago, renovación) para que lo haga a tiempo.',
    'survey' => 'ENCUESTA de satisfacción: que conteste las preguntas (guardar_respuesta).'
  }.freeze

  def self.sanitize(raw)
    raw = Motor2::Sanitizer.plain(raw)
    out = TEXTS.index_with { |k| raw[k].to_s.strip.first(1000) }
    CHOICES.each { |k, values| out[k] = raw[k].to_s.presence_in(values) || values.first }
    out.merge(ids(raw)).merge(lists(raw)).merge(Motor2::Functions::Extras.sanitize(raw)).compact
  end

  def self.ids(raw)
    %w[user_id team_id event_id appointment_minutes].index_with { |k| raw[k].to_s.presence&.to_i }
                                                    .merge('low_score' => (raw['low_score'].presence || LOW_SCORE).to_i.clamp(1, 10))
  end

  def self.lists(raw)
    { 'survey_questions' => Array(raw['survey_questions']).map { |q| q.to_s.squish.first(300) }.compact_blank.first(MAX_QUESTIONS),
      'appointment_user_ids' => Array(raw['appointment_user_ids']).map(&:to_i).select(&:positive?).uniq,
      'objections' => Array(raw['objections']).filter_map { |o| Motor2::Functions::ProspectAnswers.objection_row(Motor2::Sanitizer.plain(o)) }
                                              .first(Motor2::Functions::Prospects::MAX_OBJECTIONS) }
  end

  attr_reader :config

  delegate :answers, to: :config

  def initialize(config)
    @config = config
  end

  def key = KEY

  def answer(name) = answers[name.to_s]

  def purpose = answer(:purpose).to_s.presence_in(PURPOSES) || 'offer'

  def tone = (TONES[answer(:tone)] || TONES['cercano']).first

  def survey? = purpose == 'survey'

  def invite? = purpose == 'invite'

  def appointment? = !survey? && !invite? && answer(:offer_goal) == 'appointment' && appointment_user_ids.any?

  def appointment_user_ids = Array(answer(:appointment_user_ids)).map(&:to_i)

  def survey_questions = Array(answer(:survey_questions)).map(&:to_s).compact_blank

  def low_score = (answer(:low_score).presence || LOW_SCORE).to_i

  # Encuesta: las preguntas con tipo y si esa respuesta es baja (TrackingCampaigns::SurveyItems).
  def survey_items = Array(answer(:survey_items))

  def low_answer?(number, value) = TrackingCampaigns::SurveyItems.low?(survey_items, number, value, low_score)

  def relay_to_person? = answer(:relay) == 'person'

  def handoff_target = { user_id: answer(:user_id), team_id: answer(:team_id) }

  def event
    return @event if defined?(@event)

    @event = answer(:event_id).present? ? config.account.events.find_by(id: answer(:event_id)) : nil
  end

  def skills
    { 'campaign' => { 'on' => true },
      'knowledge' => { 'on' => !survey? },
      'recommend' => { 'on' => !survey? && price_source == 'catalog' },
      'quote' => { 'on' => !survey? && quote_mode != 'off' },
      'handoff' => { 'on' => true, 'when' => 'pide hablar con una persona o se molesta' }.merge(handoff_target.transform_keys(&:to_s)),
      'appointments' => { 'on' => appointment?, 'kind' => 'llamada', 'when' => 'le interesa y quiere una cita',
                          'user_ids' => appointment_user_ids, 'minutes' => answer(:appointment_minutes) } }
  end

  def outcomes(tracking, conversation) = Motor2::Functions::CampaignSellerOutcomes.new(tracking, conversation, self)

  def prompt(conversation = nil)
    [Motor2::Functions.puesto(KEY), offer_block, facts_block, links_block, contact_block(conversation), business_block,
     objections_block].map { |b| b.to_s.strip }.compact_blank.join("\n\n")
  end

  GOAL_TEXT = {
    'confirm' => 'que confirme si va (confirmar_asistencia).',
    'external' => 'que lo haga por su cuenta con la liga y te avise escribiendo «%<kw>s». Lo logró SOLO cuando escribe ' \
                  '«%<kw>s» o confirma sin duda que YA lo hizo (ya_lo_hizo); «me interesa» o «ahorita lo hago» NO cuentan.',
    'done' => 'que lo haga y te confirme que YA lo hizo (ya_lo_hizo); «sí, luego lo hago» no cuenta.',
    'relay' => 'que le interese: en cuanto lo quiera, pásalo a quien sigue (le_interesa).',
    'appointment' => 'que agende una cita (ver_horarios y agendar_cita).',
    'answers' => 'que conteste la encuesta (guardar_respuesta).'
  }.freeze

  def goal = TrackingCampaigns::CampaignKit.goal(purpose, answer(:offer_goal))

  def keyword = answer(:goal_keyword).presence || TrackingCampaigns::CampaignKit.kit(purpose)[:keyword]

  def external? = %w[external done].include?(goal)

  def brief = { 'kind' => purpose, 'offer_goal' => goal, 'replies' => answer(:replies), 'labels' => answer(:labels) }.compact

  # La respuesta fija (la de la campaña o la de fábrica) y la etiqueta del contacto.
  def reply_text(key) = TrackingCampaigns::CampaignKit.reply(brief, key)

  def label_for(key) = TrackingCampaigns::CampaignKit.label(brief, key)

  def asks_future? = TrackingCampaigns::CampaignKit.asks_future?(purpose) && reply_text('not_now').present?

  def facts = answer(:facts).to_h

  def links = Array(answer(:links))

  # LA CAMPAÑA (también la usa el entrenador del probador).
  def offer_block
    lines = ["LA CAMPAÑA — para qué es: #{PURPOSE_TEXT[purpose]}"]
    lines << "- Qué cuenta como logrado: #{format(GOAL_TEXT[goal], kw: keyword)}"
    lines << "- Qué: #{answer(:offer_what)}" if answer(:offer_what).present?
    lines << event_line if invite? && event
    lines << content_line if content.present?
    lines.join("\n")
  end

  AUDIENCE_FACTS = %w[audience not_for].freeze

  def facts_block
    rows = TrackingCampaigns::CampaignKit.facts(purpose).filter_map do |k|
      note = AUDIENCE_FACTS.include?(k) ? ' (para contestar si pregunta; no se lo preguntes)' : ''
      "- #{TrackingCampaigns::CampaignKit::FACT_LABELS[k]}#{note}: #{facts[k]}" if facts[k].present?
    end
    # El vendedor de Agentes listos (sin campaña) trae su «precio, vigencia y condiciones».
    rows << "- Precio, vigencia y condiciones: #{answer(:offer_details)}" if answer(:offer_details).present?
    rows.concat(offer_rows)
    return '' if rows.empty?

    'LA FICHA (es lo ÚNICO que sabes de esta campaña y lo puedes decir, aunque sea un precio o costo; si te preguntan algo ' \
      "que no está aquí ni en tus fuentes, di que no tienes ese dato confirmado y no lo inventes):\n#{rows.join("\n")}"
  end

  # Ofrecer: los productos del Catálogo con su precio de promoción y la vigencia (TrackingCampaigns::OfferProducts).
  def offer_rows
    products = Array(answer(:products))
    return [] if products.empty? && answer(:valid_until).blank?

    rows = TrackingCampaigns::OfferProducts.lines(config.account, products, answer(:valid_until))
    rows.unshift('- Productos de la promoción (precio normal → de promoción):') if rows.any?
    [*rows, TrackingCampaigns::OfferProducts.vigencia_line(answer(:valid_until))].compact
  end

  # Para cotizar: el precio de promoción de ese producto mientras dure (Motor2::Skills::Quote).
  def promo_price_for(catalog_item)
    TrackingCampaigns::OfferProducts.promo_price(answer(:products), answer(:valid_until), catalog_item)
  end

  LINK_USE = {
    'package' => 'va con la información completa y se la vuelves a mandar cada vez que la pida',
    'request' => 'solo si la pide',
    'problem' => 'SOLO si tiene un problema para entrar o hacerlo (no le llegó el correo, la otra no le abre); nunca con la información'
  }.freeze

  def links_block
    return '' if links.empty?

    rows = links.map { |l| "- #{l['name']}: #{l['url']} — #{LINK_USE[l['use']] || LINK_USE['request']}#{". #{l['note']}" if l['note'].present?}" }
    "LIGAS (cópialas EXACTAS; no son intercambiables: si pide «la liga» y no se entiende cuál, pregúntale):\n#{rows.join("\n")}"
  end

  # Datos de ESTE contacto (lo último que compró, lo que le vence): Reactivar y Recordar.
  def contact_block(conversation)
    contact = conversation.try(:contact)
    return '' unless contact.is_a?(Contact) && %w[reactivate renew].include?(purpose)

    rows = TrackingCampaigns::ContactFacts.new(contact).lines
    rows.empty? ? '' : "DATOS DE ESTE CONTACTO (úsalos con tacto; no le recites todo):\n#{rows.join("\n")}"
  end

  # «El paquete» (WhatsApp): sale tal cual con enviar_informacion; también lo puedes usar para contestar.
  def content = answer(:content).to_s.strip

  def content_line
    "- LO QUE DICE LA INFORMACIÓN QUE SE LE MANDA (con enviar_informacion, tal cual; no la escribas tú):\n" \
      "#{content.first(TrackingCampaigns::Motor2Brief::MAX_CONTENT)}"
  end

  private

  def event_line
    when_text = Motor2::Skills::Appointments.label(event.starts_at.in_time_zone(config.zone))
    ["- El evento: «#{event.name}», #{when_text}", *event_extras].compact.join(' ')
  end

  def event_extras
    [event.location.presence && "en #{event.location}", event.meeting_url.presence && "(liga: #{event.meeting_url})",
     event.description.presence && "— #{event.description.to_s.squish.first(400)}"]
  end

  def business_block
    lines = BUSINESS.filter_map { |k, label| "- #{label}: #{own_business(k)}" if own_business(k).present? }
    lines << price_line unless survey?
    lines.empty? ? '' : "EL NEGOCIO:\n#{lines.join("\n")}"
  end

  # Las de la campaña (de esta oferta) primero; de las generales del vendedor, las que la campaña no repite.
  def objection_rows
    own = Array(answer(:campaign_objections))
    taken = own.map { |o| o['objection'].to_s.squish.downcase }
    own + Array(answer(:objections)).reject { |o| taken.include?(o['objection'].to_s.squish.downcase) }
  end

  def objections_block
    rows = objection_rows.select { |o| o['objection'].present? && o['answer'].present? }
    return '' if rows.empty?

    "PREGUNTAS Y OBJECIONES AUTORIZADAS (contesta con esta idea, con tus palabras; no ofrezcas descuentos que no estén aquí):\n" \
      "#{rows.map { |o| "- «#{o['objection']}» → #{o['answer']}" }.join("\n")}"
  end
end
