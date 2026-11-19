# frozen_string_literal: true

# Función «Vendedor de campaña» (Plan-Motor-Agentes §11.16): toca la puerta. La campaña manda el primer
# mensaje (plantilla del agente) y el agente sigue cuando contesta: despierta el interés en la oferta,
# resuelve 2–3 dudas y pasa el relevo (Motor2::Relay) a quien sigue. Lo que contestó en su asistente
# (motor2['answers']):
#
#   purpose          invite | offer | reactivate | renew | survey (para qué es la campaña)
#   offer_what       qué ofrece (o a qué invita)            offer_details  precio, vigencia, condiciones
#   offer_goal       relay (si le interesa → relevo) | appointment (le agenda la cita)
#   event_id         Invitar: el evento de Eventos (fecha, lugar, liga salen de ahí)
#   survey_questions Encuesta: hasta 3 preguntas, tal cual · low_score: menor a esto (0–10) es «baja»
#   relay            agent (al agente de la bandeja: prospectos o clientes) | person · user_id / team_id
#   objections       [{ objection, answer }] · tone · business_* · price_source
#   appointment_user_ids / appointment_minutes (con offer_goal = appointment)
#
# La oferta vive en el agente por ahora; la pantalla de campañas podrá mandar la suya (brief) después.
class Motor2::Functions::CampaignSeller
  include Motor2::Functions::ProspectPrices

  KEY = 'campaign_seller'
  PURPOSES = %w[invite offer reactivate renew survey].freeze
  TEXTS = %w[tone purpose offer_what offer_details offer_goal relay price_source business_what business_who
             business_coverage business_why business_practical].freeze
  CHOICES = { 'purpose' => PURPOSES, 'offer_goal' => %w[relay appointment], 'relay' => %w[agent person] }.freeze
  MAX_QUESTIONS = 3
  LOW_SCORE = 7
  BUSINESS = Motor2::Functions::Prospects::BUSINESS
  TONES = Motor2::Functions::Prospects::TONES
  PURPOSE_TEXT = {
    'invite' => 'INVITAR al evento: que confirme si va (confirmar_asistencia).',
    'offer' => 'OFRECER: que le interese la oferta.',
    'reactivate' => 'REACTIVAR a un cliente que hace tiempo no compra: que le interese volver.',
    'renew' => 'RECORDAR / RENOVAR: que renueve o aproveche antes de que venza.',
    'survey' => 'ENCUESTA de satisfacción: que conteste las preguntas (guardar_respuesta).'
  }.freeze

  def self.sanitize(raw)
    raw = Motor2::Sanitizer.plain(raw)
    out = TEXTS.index_with { |k| raw[k].to_s.strip.first(1000) }
    CHOICES.each { |k, values| out[k] = raw[k].to_s.presence_in(values) || values.first }
    out.merge(ids(raw)).merge(lists(raw)).compact
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

  def relay_to_person? = answer(:relay) == 'person'

  def handoff_target = { user_id: answer(:user_id), team_id: answer(:team_id) }

  def event
    return @event if defined?(@event)

    @event = answer(:event_id).present? ? config.account.events.find_by(id: answer(:event_id)) : nil
  end

  def business_values = BUSINESS.keys.map { |k| answer(k).to_s }

  def skills
    { 'campaign' => { 'on' => true },
      'knowledge' => { 'on' => !survey? },
      'handoff' => { 'on' => true, 'when' => 'pide hablar con una persona o se molesta' }.merge(handoff_target.transform_keys(&:to_s)),
      'appointments' => { 'on' => appointment?, 'kind' => 'llamada', 'when' => 'le interesa y quiere una cita',
                          'user_ids' => appointment_user_ids, 'minutes' => answer(:appointment_minutes) } }
  end

  def outcomes(tracking, conversation) = Motor2::Functions::CampaignSellerOutcomes.new(tracking, conversation, self)

  def prompt(_conversation = nil)
    [Motor2::Functions.puesto(KEY), offer_block, business_block, objections_block].map { |b| b.to_s.strip }.compact_blank.join("\n\n")
  end

  # LA OFERTA (también la usa el entrenador del probador).
  def offer_block
    lines = ["LA OFERTA — para qué es la campaña: #{PURPOSE_TEXT[purpose]}"]
    lines << "- Qué: #{answer(:offer_what)}" if answer(:offer_what).present?
    lines << "- Precio, vigencia y condiciones: #{answer(:offer_details)}" if answer(:offer_details).present?
    lines << event_line if invite? && event
    lines << '- Si le interesa: agéndale la cita (ver_horarios y agendar_cita).' if appointment?
    lines.join("\n")
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
    lines = BUSINESS.filter_map { |k, label| "- #{label}: #{answer(k)}" if answer(k).present? }
    lines << price_line unless survey?
    lines.empty? ? '' : "EL NEGOCIO:\n#{lines.join("\n")}"
  end

  def objections_block
    rows = Array(answer(:objections)).select { |o| o['objection'].present? && o['answer'].present? }
    return '' if rows.empty?

    "OBJECIONES FRECUENTES (contesta con esta idea, con tus palabras; no ofrezcas descuentos que no estén aquí):\n" \
      "#{rows.map { |o| "- «#{o['objection']}» → #{o['answer']}" }.join("\n")}"
  end
end
