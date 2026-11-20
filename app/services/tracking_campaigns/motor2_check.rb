# frozen_string_literal: true

# Campaña con Vendedor IA — la revisión antes de lanzar (paso «Revisar y lanzar»): cada punto en verde, amarillo
# (aviso) o rojo (no deja lanzar).
#
#   TrackingCampaigns::Motor2Check.new(campaign).call → [{ key:, level: 'ok' | 'warning' | 'error', text: }]
#   #ready? → sin rojos
class TrackingCampaigns::Motor2Check
  def initialize(campaign)
    @campaign = campaign
    @brief = campaign.brief.to_h
    @touches = campaign.touches.to_h
  end

  def call
    @call ||= [seller, offer, audience, channel, *touch_items, relay, window].compact
  end

  def ready? = call.none? { |item| item[:level] == 'error' }

  private

  def item(key, level, text) = { key: key, level: level, text: text }

  def seller
    agent = @campaign.tracking_template
    return item(:seller, 'error', 'Elige el Vendedor de campaña.') unless agent && agent.archived_at.nil?

    item(:seller, 'ok', "La atiende «#{agent.name}».")
  end

  def offer
    case @brief['kind']
    when 'invite' then invite
    when 'survey'
      return item(:offer, 'error', 'Escribe al menos una pregunta de la encuesta.') if Array(@brief['survey_questions']).empty?

      item(:offer, 'ok', "Encuesta de #{@brief['survey_questions'].size} pregunta(s).")
    else
      @brief['offer_what'].present? ? item(:offer, 'ok', 'La oferta está escrita.') : item(:offer, 'error', 'Escribe qué ofreces.')
    end
  end

  def invite
    event = @campaign.account.events.find_by(id: @brief['event_id'])
    return item(:offer, 'error', 'Elige el evento al que invitas.') unless event
    return item(:offer, 'error', "El evento «#{event.name}» ya pasó.") if event.starts_at && event.starts_at < Time.current

    item(:offer, 'ok', "Invita a «#{event.name}».")
  end

  def audience
    return item(:audience, 'warning', 'Continua: entran los que agreguen tus automatizaciones («Agregar a campaña»).') if @campaign.continuous?

    data = @campaign.audience.to_h
    chosen = Array(data['filter_payload']).any? || Array(data['contact_ids']).any?
    chosen ? item(:audience, 'ok', 'La audiencia está elegida.') : item(:audience, 'error', 'Elige a quién se le manda.')
  end

  def channel
    inbox = @campaign.inbox
    return item(:channel, 'error', 'Elige la bandeja de WhatsApp o de correo.') unless inbox

    item(:channel, 'ok', "Sale por «#{inbox.name}».")
  end

  def touch_items
    return [] unless @campaign.inbox

    @campaign.inbox.whatsapp? ? whatsapp_touches : email_touches
  end

  # WhatsApp: a quien no ha escrito solo se le puede escribir con plantilla aprobada, en cada toque.
  def whatsapp_touches
    approved = approved_templates
    (1..attempts).map do |n|
      name = Array(@touches['templates'])[n - 1].presence
      next item(:"touch_#{n}", 'error', "Toque #{n}: elige su plantilla de WhatsApp.") unless name
      next item(:"touch_#{n}", 'error', "Toque #{n}: la plantilla «#{name}» no está aprobada o ya no existe.") unless approved.include?(name)

      item(:"touch_#{n}", 'ok', "Toque #{n}: plantilla «#{name}».")
    end
  end

  def email_touches
    subject = if @campaign.email_subject.present?
                item(:subject, 'ok',
                     'El asunto está escrito.')
              else
                item(:subject, 'error', 'Escribe el asunto del correo.')
              end
    written = (1..attempts).count { |n| TrackingCampaigns::Motor2Brief.email_body(@campaign, n) }
    body = if written == attempts
             item(:bodies, 'ok', "Los #{attempts} correos están escritos.")
           else
             item(:bodies, 'warning', "#{attempts - written} correo(s) sin texto: los escribe el agente con IA para cada contacto.")
           end
    [subject, body]
  end

  def approved_templates
    Array(@campaign.inbox.channel.try(:message_templates)).select { |t| t['status'].to_s.casecmp('approved').zero? }.pluck('name')
  end

  def relay
    return nil if @brief['kind'] == 'survey'

    answers = @campaign.tracking_template&.motor2.to_h['answers'].to_h
    return item(:relay, 'ok', 'Si le interesa, lo pasa al agente de atención de la bandeja.') unless answers['relay'] == 'person'

    if answers['user_id'].present? || answers['team_id'].present?
      return item(:relay, 'ok',
                  'Si le interesa, lo pasa a la persona o equipo del agente.')
    end

    item(:relay, 'warning', 'El agente no tiene a quién pasar a los interesados: elígelo en su pestaña «Cómo platica».')
  end

  def window
    return item(:window, 'error', 'La fecha de fin ya pasó.') if @campaign.ends_at && @campaign.ends_at <= Time.current

    start = @campaign.scheduled_for
    text = start && start > Time.current ? "Empieza el #{I18n.l(start, format: :short)}." : 'Empieza en cuanto la lances.'
    item(:window, 'ok', text)
  end

  def attempts = (@touches['attempts'].presence || 1).to_i
end
