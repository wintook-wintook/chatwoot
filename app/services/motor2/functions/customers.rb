# frozen_string_literal: true

# Función «Atención a clientes» (Plan-Motor-Agentes §11.15) — convierte lo que la empresa contestó en
# su asistente (motor2['answers']) en el prompt y las habilidades del motor 2.0:
#
#   areas            Soporte / Comercial / Administrativo / Otra (Motor2::Functions::CustomerAreas)
#   tone             cercano | formal | directo
#   business_*       qué vende, a quién, dónde…  · price_source (Motor2::Functions::ProspectPrices)
#   not_client       serve (lo atiende igual) | handoff (lo pasa a una persona sin atenderlo). Si en la bandeja
#                    también hay un agente de «Atención a prospectos», los que no son clientes van con él
#                    (Motor2::InboxRouter) y esto ni aplica.
#   human            understand_first (primero entiende qué necesita y lo pasa al equipo de esa área) | now
#   identify         ask (si no se sabe de qué empresa es, se lo pregunta una vez: Motor2::Skills::Identity) | no
#   goal             none (solo atender) | appointment (que agende) | quote (que cotice) · goal_mode soft | active
#                    (Motor2::Skills::Goal)
#   user_id/team_id  a quién se pasa lo que no tiene área (o si el área no dice)
#
# Qué área toca en cada mensaje lo decide el código (Motor2::Triage, en Motor2::Skills::Areas), no el
# modelo que contesta.
class Motor2::Functions::Customers
  include Motor2::Functions::ProspectPrices
  include Motor2::Functions::Extras

  KEY = 'customers'
  TEXTS = %w[tone price_source business_what business_who business_coverage business_why business_practical].freeze
  OPTIONS = { 'not_client' => %w[serve handoff], 'human' => %w[understand_first now], 'identify' => %w[ask no],
              'goal' => %w[none appointment quote], 'goal_mode' => %w[soft active] }.freeze
  BUSINESS = Motor2::Functions::Prospects::BUSINESS
  TONES = Motor2::Functions::Prospects::TONES

  def self.sanitize(raw)
    raw = Motor2::Sanitizer.plain(raw)
    out = TEXTS.index_with { |k| raw[k].to_s.strip.first(1000) }
    OPTIONS.each { |k, values| out[k] = raw[k].to_s.presence_in(values) || values.first }
    %w[user_id team_id].each { |k| out[k] = raw[k].to_s.presence&.to_i }
    out.merge('areas' => Motor2::Functions::CustomerAreas.sanitize(raw['areas'])).merge(Motor2::Functions::Extras.sanitize(raw)).compact
  end

  attr_reader :config

  delegate :answers, to: :config

  def initialize(config)
    @config = config
  end

  def key = KEY

  def answer(name) = answers[name.to_s]

  def tone = (TONES[answer(:tone)] || TONES['cercano']).first

  def option(name) = answer(name).to_s.presence_in(OPTIONS[name.to_s]) || OPTIONS[name.to_s].first

  def human_now? = option(:human) == 'now'

  # Quien no es cliente no lo atiende: se pasa a una persona (Motor2::InboxRouter.start).
  def clients_only? = option(:not_client) == 'handoff'

  # Las áreas prendidas, con su configuración.
  def areas = Motor2::Functions::CustomerAreas.active(answer(:areas))

  def area(key) = areas.find { |a| a['key'] == key.to_s }

  # A quién se pasa: el del área (si lo tiene) o el general.
  def handoff_target(area_key = nil)
    data = area(area_key).to_h
    user, team = data['user_id'].present? || data['team_id'].present? ? [data['user_id'], data['team_id']] : [answer(:user_id), answer(:team_id)]
    { user_id: user, team_id: team }
  end

  def skills
    { 'areas' => { 'on' => true }, 'identity' => { 'on' => option(:identify) == 'ask' },
      'recommend' => { 'on' => price_source == 'catalog' && area('sales').present? },
      'quote' => { 'on' => quote_mode != 'off' && area('sales').present? },
      'handoff' => { 'on' => true, 'when' => 'pide una persona (como dice REGLAS DE ATENCIÓN), se molesta, o lo pide su área' }
        .merge(handoff_target.transform_keys(&:to_s)),
      'appointments' => appointments, 'goal' => goal_skill }
  end

  # «¿Qué quieres que logre?» (Motor2::Skills::Goal): solo atender, agendar la cita o cotizar.
  def goal_skill = { 'on' => option(:goal) != 'none', 'goal' => option(:goal), 'mode' => option(:goal_mode) }

  # Demo o visita de Comercial con «agendar», o la visita técnica de Soporte: la cita con las personas elegidas.
  # Citas de servicio (estética, consultorio…): en el lugar, con la duración de los servicios del Catálogo.
  def appointments
    return technical_visit if support_visit?

    sales = area('sales').to_h
    return service_booking(sales) if booking?

    wants = %w[demo visit].any? { |k| sales[k] == 'appointment' }
    { 'on' => wants && Array(sales['appointment_user_ids']).any?, 'kind' => sales['visit'] == 'appointment' ? 'visita' : 'videollamada',
      'when' => 'pide una demo o una visita', 'user_ids' => Array(sales['appointment_user_ids']), 'minutes' => sales['appointment_minutes'] }
  end

  def booking? = area('sales').to_h['booking'] == 'appointment'

  def service_booking(sales)
    { 'on' => Array(sales['appointment_user_ids']).any?, 'kind' => 'oficina', 'services' => true,
      'when' => 'quiere agendar un servicio', 'location' => business_info(:business_coverage).to_s.first(200).presence,
      'user_ids' => Array(sales['appointment_user_ids']), 'minutes' => sales['appointment_minutes'] }
  end

  def support_visit? = area('support').to_h['action'] == 'visit' && Array(area('support')['appointment_user_ids']).any?

  def technical_visit
    support = area('support')
    sales = area('sales').to_h
    users = (Array(support['appointment_user_ids']) + Array(sales['appointment_user_ids'])).uniq
    { 'on' => true, 'kind' => 'visita', 'when' => 'hace falta una visita técnica (o pide una demo o visita)', 'user_ids' => users,
      'minutes' => support['appointment_minutes'] || sales['appointment_minutes'] }
  end

  def outcomes(tracking, conversation) = Motor2::Functions::CustomerOutcomes.new(tracking, conversation, self)

  def prompt(_conversation = nil)
    [Motor2::Functions.puesto(KEY), business_block, areas_block, rules_block].map { |b| b.to_s.strip }.compact_blank.join("\n\n")
  end

  # Para la revisión de evidencia de Comercial (Motor2::AreaChecks): lo que la empresa escribió de su negocio.
  def business_evidence
    lines = BUSINESS.filter_map { |k, label| "- #{label}: #{business_info(k)}" if business_info(k).present? }
    lines.any? ? "EL NEGOCIO (lo escribió la empresa):\n#{lines.join("\n")}" : nil
  end

  # Para el entrenador del probador: lo que eligió la empresa.
  def rules_block
    sales = area('sales').to_h
    lines = ['REGLAS DE ATENCIÓN (las eligió la empresa; mandan sobre lo anterior):']
    lines << "- Tono: #{(TONES[answer(:tone)] || TONES['cercano']).last}."
    lines << (human_now? ? '- Si pide una persona, pásalo de inmediato al equipo de lo que necesita (canalizar).' : HUMAN_FIRST)
    lines.push(SALES_EVIDENCE, NO_VARIANTS) if area('sales')
    if area('sales')
      lines << "- Cotización: #{sales['quote'] == 'opportunity' ? 'regístrala (registrar_gestion)' : 'pásala al vendedor (registrar_gestion)'}."
    end
    lines.join("\n")
  end

  NO_VARIANTS = '- No preguntes por opciones que tus fuentes no tienen («¿para hombre o mujer?», tamaños, marcas): si solo ' \
                'hay un producto o servicio que coincide con lo que pidió, es ese.'
  HUMAN_FIRST = '- Si pide una persona: con gusto; si todavía no sabes qué necesita, pregúntaselo UNA vez (para pasarlo al ' \
                'equipo correcto) y luego canalízalo. Si lo vuelve a pedir, canalízalo ya.'
  SALES_EVIDENCE = '- Comercial: contesta SOLO lo que confirmen tus fuentes o EL NEGOCIO. Si no lo confirman exacto, di que no lo puedes ' \
                   'confirmar; no ofrezcas algo parecido en su lugar (una demo no sustituye una visita).'

  private

  def business_block
    lines = BUSINESS.filter_map { |k, label| "- #{label}: #{own_business(k)}" if own_business(k).present? }
    lines << price_line
    "EL NEGOCIO:\n#{lines.join("\n")}"
  end

  def areas_block
    list = areas.map { |a| "- #{a['title']}: #{a['when']}" }
    list.empty? ? '' : "LO QUE ATIENDES:\n#{list.join("\n")}"
  end
end
