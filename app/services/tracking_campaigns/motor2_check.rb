# frozen_string_literal: true

# Campaña con IA — la revisión antes de lanzar (paso «Revisar y lanzar»): cada punto en verde, amarillo
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
    @call ||= [seller, ai, offer, *knowledge, appointment, audience, channel, *list_items, *domain_items, *touch_items, *plan.whatsapp_flow,
               *plan.seller_templates, plan.cost, relay, window, plan.capacity, reminders].compact
  end

  def knowledge = TrackingCampaigns::Motor2KnowledgeCheck.new(@campaign).call + TrackingCampaigns::Motor2FileCheck.new(@campaign).call

  def ready? = call.none? { |item| item[:level] == 'error' }

  private

  def item(key, level, text) = { key: key, level: level, text: text }

  def seller
    agent = @campaign.tracking_template
    return item(:seller, 'error', 'Revisa el paso «Cómo atiende».') unless agent && agent.archived_at.nil?

    name = agent.customer_display_name.presence
    item(:seller, 'ok', name ? "Atiende como «#{name}»." : 'Cómo atiende está listo.')
  end

  # Sin OpenAI en la cuenta el vendedor no puede contestar (ni escribir los toques sin texto).
  def ai
    return nil if @campaign.account.hooks.exists?(app_id: 'openai', status: 'enabled')

    item(:ai, 'error', 'La cuenta no tiene la integración de OpenAI: el vendedor no podría contestar. Actívala en Integraciones.')
  end

  def plan = @plan ||= TrackingCampaigns::Motor2PlanCheck.new(@campaign, answers, attempts)

  def answers = @answers ||= @campaign.tracking_template&.motor2.to_h['answers'].to_h

  # «Le agenda la cita» necesita con quién: los calendarios del vendedor.
  def appointment
    return nil unless @brief['offer_goal'] == 'appointment' && %w[survey invite].exclude?(@brief['kind'])
    return item(:appointment, 'ok', 'Agenda citas en los calendarios del vendedor.') if Array(answers['appointment_user_ids']).any?

    where = %w[offer reactivate].include?(@brief['kind']) ? '«Cuando le interesa»' : '«Cómo atiende»'
    item(:appointment, 'error', "La meta es agendar cita, pero no hay con quién: elige los calendarios en #{where}.")
  end

  def offer
    case @brief['kind']
    when 'invite' then invite
    when 'renew' then item(:offer, 'ok', 'Recuerda los contratos por vencer (lo que le vence sale de cada contrato).')
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
    return item(:offer, 'error', "El evento «#{event.name}» ya pasó.") if event.starts_at && event.starts_at < today_start
    return item(:offer, 'warning', "El evento «#{event.name}» ya empezó hoy.") if event.starts_at && event.starts_at < Time.current

    item(:offer, 'ok', "Invita a «#{event.name}».")
  end

  # Invitar: los recordatorios (EventReminders.check); Ofrecer y Reactivar con vigencia: el «Último aviso» (LastCall.check).
  def reminders
    return item(:reminders, *TrackingCampaigns::EventReminders.check(@campaign)) if @brief['kind'] == 'invite'

    last_call = TrackingCampaigns::LastCall.check(@campaign)
    last_call && item(:last_call, *last_call)
  end

  # Un evento de hoy todavía se puede invitar (hora de México).
  def today_start
    Time.current.in_time_zone('America/Mexico_City').beginning_of_day
  end

  def audience
    return item(:audience, 'warning', 'Continua: entran los que agreguen tus automatizaciones («Agregar a campaña»).') if @campaign.continuous?

    data = @campaign.audience.to_h
    chosen = Array(data['filter_payload']).any? || Array(data['contact_ids']).any?
    chosen ? item(:audience, 'ok', 'La audiencia está elegida.') : item(:audience, 'error', 'Elige a quién se le manda.')
  end

  # Lista fría de correo: solo por correo, con tope diario (los rebotes y las quejas queman el buzón).
  def list_items
    return [] unless @campaign.audience.to_h.dig('source', 'type') == 'list'
    return [item(:list, 'error', 'Una lista subida solo se puede mandar por correo.')] unless @campaign.inbox&.email?

    cap = @campaign.daily_cap.to_i
    [cap.zero? ? item(:daily_cap, 'error', 'Con una lista fría pon un máximo por día (empieza con 50 a 100).') : nil,
     cap > 200 ? item(:daily_cap, 'warning', "#{cap} al día es mucho para una lista fría: sube poco a poco.") : nil,
     warmup_item(cap),
     item(:list_inbox, 'warning', 'Para listas frías usa una bandeja o dominio aparte, no el correo principal de tu empresa.')].compact
  end

  def warmup_item(cap)
    return nil if cap.zero?

    unless @brief['warmup']
      return item(:warmup, 'warning',
                  'Si el dominio es nuevo, prende «Calentar el dominio»: empieza con 50 al día y sube solo.')
    end

    item(:warmup, 'ok', "Calentando el dominio: 50 el primer día, luego 100, 200… hasta #{cap} al día.")
  end

  # Correo: el dominio de la bandeja (SPF, DKIM, DMARC). Con lista fría, sin SPF o con un correo gratis no se lanza.
  def domain_items
    return [] unless @campaign.inbox&.email?

    check = TrackingCampaigns::EmailDomainCheck.call(@campaign.inbox.channel.try(:email))
    if check[:free]
      return [item(:domain, list? ? 'error' : 'warning',
                   "«#{check[:domain]}» es un correo gratis: para campañas usa el de tu dominio.")]
    end

    [spf_item(check), dkim_item(check), dmarc_item(check)]
  end

  def spf_item(check)
    return item(:spf, 'ok', "#{check[:domain]}: SPF listo.") if check[:spf]
    return item(:spf, 'warning', "No se pudo revisar el SPF de #{check[:domain]}.") if check[:spf].nil?

    item(:spf, list? ? 'error' : 'warning',
         "#{check[:domain]} no tiene SPF: tu correo caerá en spam. Agrégalo en el DNS (te lo da tu proveedor de correo).")
  end

  def dkim_item(check)
    return item(:dkim, 'ok', "#{check[:domain]}: DKIM listo.") if check[:dkim]

    item(:dkim, 'warning', "No encontramos la firma DKIM de #{check[:domain]}: confírmala con tu proveedor de correo.")
  end

  def dmarc_item(check)
    return item(:dmarc, 'ok', "#{check[:domain]}: DMARC listo.") if check[:dmarc]

    item(:dmarc, 'warning', "#{check[:domain]} no tiene DMARC: Gmail y Yahoo lo piden para envíos masivos (un TXT en _dmarc.#{check[:domain]}).")
  end

  def list? = @campaign.audience.to_h.dig('source', 'type') == 'list'

  def channel
    inbox = @campaign.inbox
    return item(:channel, 'error', 'Elige la bandeja de WhatsApp o de correo.') unless inbox
    # WhatsApp de prueba (rake whatsapp:test_inbox): sirve para armar y simular, no envía.
    return item(:channel, 'error', "«#{inbox.name}» es de prueba: no envía. Elige una bandeja real para lanzar.") if sandbox?(inbox)

    item(:channel, 'ok', "Sale por «#{inbox.name}».")
  end

  def touch_items
    return [] unless @campaign.inbox

    @campaign.inbox.whatsapp? ? whatsapp_touches : email_touches
  end

  def whatsapp_touches = TrackingCampaigns::Motor2TouchCheck.new(@campaign, attempts).call

  # WhatsApp de prueba (rake whatsapp:test_inbox): sirve para armar y simular, no envía.
  def sandbox?(inbox) = inbox.whatsapp? && inbox.channel.provider_config.to_h['sandbox'].present?

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

  def relay
    return nil if @brief['kind'] == 'survey'

    merged = answers.merge(TrackingCampaigns::Motor2Brief.relay_answers(@brief))
    whose = @brief['relay'].present? ? 'de la campaña' : 'del vendedor'
    person = merged['user_id'].present? || merged['team_id'].present?
    return relay_to_agent(person) unless merged['relay'] == 'person'
    return item(:relay, 'ok', "Si le interesa, lo pasa a la persona o equipo #{whose}.") if person

    if @brief['kind'] == 'invite' # Invitar no pasa interesados: solo al que pide una persona
      return item(:relay, 'warning', 'Si alguien pide hablar con una persona, no hay a quién pasarlo: elígelo en «Cuando contesta».')
    end

    item(:relay, 'error', "No hay a quién pasar a los interesados: elige persona o equipo en #{relay_step}.")
  end

  def relay_step = %w[offer reactivate].include?(@brief['kind']) ? '«Cuando le interesa»' : '«Cómo atiende» (Si le interesa, pasa a)'

  # Al agente de la bandeja: si la bandeja no tiene agente que atienda, cae a la persona del vendedor.
  def relay_to_agent(person)
    agent = @campaign.inbox && Motor2::InboxRouter.principal(@campaign.account_id, @campaign.inbox_id)
    return item(:relay, 'ok', "Si le interesa, lo pasa a «#{agent.name}», el agente de la bandeja.") if agent
    return item(:relay, 'warning', 'La bandeja no tiene agente que atienda: los interesados pasan a la persona o equipo.') if person

    item(:relay, 'error', 'La bandeja no tiene agente que atienda y no hay persona o equipo: los interesados quedarían sin nadie.')
  end

  def window
    return item(:window, 'error', 'La fecha de fin ya pasó.') if @campaign.ends_at && @campaign.ends_at <= Time.current

    start = @campaign.scheduled_for
    return item(:window, 'error', 'La fecha de fin es antes del inicio.') if ends_before_start?

    text = start && start > Time.current ? "Empieza el #{I18n.l(start, format: :short)}." : 'Empieza en cuanto la lances.'
    item(:window, 'ok', text)
  end

  def ends_before_start? = @campaign.scheduled_for && @campaign.ends_at && @campaign.ends_at <= @campaign.scheduled_for

  def attempts = (@touches['attempts'].presence || 1).to_i
end
