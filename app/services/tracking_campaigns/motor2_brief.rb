# frozen_string_literal: true

# Campaña con Vendedor IA (Motor 2.0) — lo que trae la campaña y no el agente:
#
#   brief    { kind        offer | invite | reactivate | renew | survey   (para qué es)
#              offer_what  qué ofrece / a qué invita / qué vence          offer_details precio, vigencia, condiciones
#              offer_goal  relay (si le interesa → relevo) | appointment (le agenda la cita)
#              event_id    Invitar: el evento (también arma la audiencia)
#              survey_questions [≤3] · low_score (menor a esto, de 0 a 10, es baja)
#              rest_days   no se le escribe si otra campaña 2.0 le escribió hace menos de estos días (0 = sin regla)
#              warmup      calentar el dominio: el tope diario arranca en WARMUP_START y se duplica cada día
#              content     WhatsApp, «Mensaje 2»: lo que se manda TAL CUAL cuando pide información (el copy; sus imágenes
#                          son los archivos de la oferta «con la información»). También es lo que sabe el vendedor.
#              opener      WhatsApp: la apertura cuando la ventana de 24 h está abierta (vacía: la escribe la IA)
#              objections  [{ objection, answer }] de ESTA oferta: van además de las generales del vendedor y, si es
#                          la misma objeción, gana la de la campaña
#              relay       '' (lo que diga el vendedor) | agent | person · relay_user_id / relay_team_id: quién atiende
#                          a los de esta campaña (el interesado y el que pide una persona) }
#   touches  { attempts 1..6 · every_value / every_unit (hours | days) entre toques
#              templates [nombre de plantilla de WhatsApp por toque] · template_vars { plantilla => { variable =>
#                        { source, text } } }: de dónde sale cada variable (TrackingCampaigns::TemplateVars)
#              emails    [{ body, blocks }] por toque (el asunto del primero es email_subject / email_subject_b);
#                        un cuerpo vacío lo escribe el agente con IA }
#
# El agente lo recibe como si lo hubiera contestado en su asistente (seller_answers → Motor2::Config).
module TrackingCampaigns::Motor2Brief
  KINDS = %w[offer invite reactivate renew survey].freeze
  GOALS = %w[relay appointment].freeze
  UNITS = %w[hours days].freeze
  MAX_TOUCHES = 6
  MAX_QUESTIONS = 3
  MAX_TEXT = 1500
  MAX_BODY = 6000
  WARMUP_START = 50
  TEST_EVERY_MINUTES = 3

  module_function

  # Calentando: cuántos van el día n (0, 1, 2…) desde que empezó: 50, 100, 200… hasta el tope de la campaña.
  def warmup_cap(cap, day) = [cap, WARMUP_START * (2**day.clamp(0, 20))].min

  # Calentando y por lote: en qué día (0, 1, 2…) sale el inscrito número n.
  def warmup_day(index, cap)
    day = 0
    total = warmup_cap(cap, 0)
    while index >= total
      day += 1
      total += warmup_cap(cap, day)
    end
    day
  end

  def brief(raw)
    raw = Motor2::Sanitizer.plain(raw)
    {
      'kind' => raw['kind'].to_s.presence_in(KINDS) || 'offer', 'offer_goal' => raw['offer_goal'].to_s.presence_in(GOALS) || 'relay',
      'offer_what' => text(raw['offer_what']), 'offer_details' => text(raw['offer_details']),
      'event_id' => id(raw['event_id']), 'survey_questions' => questions(raw['survey_questions']),
      'low_score' => number(raw['low_score'], 7, 1..10), 'rest_days' => number(raw['rest_days'], 0, 0..90),
      'warmup' => flag(raw['warmup'])
    }.merge(talk(raw)).compact
  end

  # Cómo atiende a los de ESTA campaña, encima del vendedor: objeciones de la oferta y el relevo.
  def talk(raw)
    { 'objections' => objections(raw['objections']), 'content' => raw['content'].to_s.strip.first(MAX_CONTENT),
      'opener' => raw['opener'].to_s.strip.first(MAX_TEXT) }.merge(relay(raw))
  end

  MAX_OBJECTIONS = 10
  MAX_CONTENT = 4000 # lo más que manda WhatsApp en un mensaje de texto es 4,096

  def objections(list)
    Array(list).filter_map { |o| Motor2::Functions::ProspectAnswers.objection_row(Motor2::Sanitizer.plain(o)) }.first(MAX_OBJECTIONS)
  end

  # Vacío: el relevo del vendedor. Con persona, la persona y el equipo de la campaña.
  def relay(raw)
    mode = raw['relay'].to_s.presence_in(%w[agent person])
    return { 'relay' => mode } unless mode == 'person'

    { 'relay' => mode, 'relay_user_id' => id(raw['relay_user_id']), 'relay_team_id' => id(raw['relay_team_id']) }
  end

  def touches(raw)
    raw = Motor2::Sanitizer.plain(raw)
    attempts = number(raw['attempts'], 2, 1..MAX_TOUCHES)
    { 'attempts' => attempts, 'every_value' => number(raw['every_value'], 2, 1..30),
      'every_unit' => raw['every_unit'].to_s.presence_in(UNITS) || 'days',
      'templates' => Array(raw['templates']).map { |t| t.to_s.strip.first(200) }.first(attempts),
      'emails' => Array(raw['emails']).first(attempts).map { |e| email(e.to_h) },
      'template_vars' => TrackingCampaigns::TemplateVars.sanitize(raw['template_vars']) }
  end

  BLOCKS = %w[heading text button image].freeze

  # Un correo: su texto (markdown, el que sale) y los bloques del editor (para volver a abrirlo igual).
  def email(raw)
    blocks = Array(raw['blocks']).first(30).filter_map do |b|
      b = b.to_h
      { 'type' => b['type'], 'text' => b['text'].to_s.first(MAX_BODY), 'url' => b['url'].to_s.strip.first(2000) } if BLOCKS.include?(b['type'])
    end
    { 'body' => raw['body'].to_s.strip.first(MAX_BODY), 'blocks' => blocks }
  end

  def questions(list) = Array(list).map { |q| q.to_s.squish.first(300) }.compact_blank.first(MAX_QUESTIONS)

  def id(value) = value.to_s.presence&.to_i

  def flag(value) = ActiveModel::Type::Boolean.new.cast(value) || false

  def number(value, default, range) = (value.presence || default).to_i.clamp(range.min, range.max)

  def text(value) = value.to_s.strip.first(MAX_TEXT)

  # Lo que el «Vendedor de campaña» usa como si viniera de su asistente (Motor2::Functions::CampaignSeller).
  def seller_answers(campaign)
    data = campaign.brief.to_h
    { 'purpose' => data['kind'], 'offer_what' => data['offer_what'], 'offer_details' => data['offer_details'],
      'offer_goal' => data['offer_goal'], 'event_id' => data['event_id'], 'survey_questions' => data['survey_questions'],
      'low_score' => data['low_score'], 'campaign_objections' => data['objections'].presence,
      'content' => data['content'].presence }.merge(relay_answers(data)).compact
  end

  # El relevo de la campaña encima del del vendedor (solo si la campaña lo eligió).
  def relay_answers(data)
    case data['relay']
    when 'agent' then { 'relay' => 'agent' }
    when 'person' then { 'relay' => 'person', 'user_id' => data['relay_user_id'], 'team_id' => data['relay_team_id'] }
    else {}
    end
  end

  # Los intentos y su ritmo para cada seguimiento (TrackingCampaigns::TrackingBuilder).
  def tracking_touches(campaign)
    data = campaign.touches.to_h
    attempts = (data['attempts'].presence || 2).to_i
    templates = campaign.inbox&.whatsapp? ? Array(data['templates']).first(attempts) : []
    { max_attempts: attempts, whatsapp_templates: templates }.merge(pace(campaign, data))
  end

  # Cada cuánto: el de la campaña; en «Prueba real», cada test_every_minutes minutos.
  def pace(campaign, data)
    if campaign.test_run?
      return { retry_interval_value: (data['test_every_minutes'].presence || TEST_EVERY_MINUTES).to_i.clamp(1, 60),
               retry_interval_unit: 'minutes' }
    end

    { retry_interval_value: (data['every_value'].presence || 2).to_i, retry_interval_unit: data['every_unit'] == 'hours' ? 'hours' : 'days' }
  end

  # El cuerpo del correo del toque n (1, 2…), o nil si lo escribe el agente.
  def email_body(campaign, touch)
    Array(campaign.touches.to_h['emails'])[touch.to_i - 1].to_h['body'].presence
  end
end
