# frozen_string_literal: true

# Campaña con Vendedor IA — «Simular»: la campaña completa para UN contacto, sin mandar ni guardar nada:
#   touches   cada toque con su espera, su canal y su texto ya personalizado (la plantilla de WhatsApp con sus
#             variables llenas, o el correo con {{contacto}} / {{empresa}}); el que no trae texto lo escribe el
#             vendedor con IA en ese momento (source: 'ai');
#   outcomes  qué pasa según cómo conteste: le interesa (relevo o cita, y a quién), no le interesa, pide una
#             persona, termina (invitación / encuesta) o nunca contesta;
#   warnings  lo que haría que un toque no salga (WhatsApp sin plantilla fuera de las 24 h, contacto sin canal…).
# El chat con el vendedor (Motor2::Probe) arranca desde el toque que el usuario elija.
#
#   TrackingCampaigns::Motor2Simulation.new(campaign, contact).call
class TrackingCampaigns::Motor2Simulation
  def initialize(campaign, contact)
    @campaign = campaign
    @contact = contact
    @inbox = campaign.inbox
    @seller = campaign.tracking_template
  end

  def call
    { contact: { id: @contact.id, name: @contact.name, address: address },
      touches: touches, outcomes: outcomes, warnings: warnings }
  end

  private

  def whatsapp? = @inbox&.whatsapp? || false

  def address = whatsapp? ? @contact.phone_number : @contact.email

  def data = @campaign.touches.to_h

  def attempts = (data['attempts'].presence || 2).to_i

  def touches
    (1..attempts).map do |n|
      { n: n, wait: wait(n), files: touch_files(n) }.merge(whatsapp? ? whatsapp_touch(n) : email_touch(n))
    end
  end

  # Los archivos que van con el toque n: los de la oferta y los del vendedor (en WhatsApp, solo si la ventana de 24 h
  # está abierta; con plantilla va la plantilla sola).
  def touch_files(touch)
    tracking = ContactTracking.new(tracking_template: @seller, tracking_campaign: @campaign)
    @seller ? ContactTrackings::AttemptFiles.names_for(tracking, touch) : []
  end

  # Cuánto después del primero sale el toque n (nil el primero).
  def wait(touch)
    return nil if touch == 1

    unit = data['every_unit'] == 'hours' ? 'hours' : 'days'
    { value: (touch - 1) * (data['every_value'].presence || 2).to_i, unit: unit }
  end

  def email_touch(touch)
    body = TrackingCampaigns::Motor2Brief.email_body(@campaign, touch)
    subject = touch == 1 ? TrackingCampaigns::EmailSubject.render(@campaign.email_subject, @contact) : nil
    return { channel: 'email', subject: subject, source: 'ai' } unless body

    { channel: 'email', subject: subject, source: 'campaign', text: Motor2::CampaignTouch.fill(body, @contact) }
  end

  # Sin plantilla para ese toque: solo sale si el contacto escribió en las últimas 24 h (lo escribe el vendedor).
  def whatsapp_touch(touch)
    name = Array(data['templates'])[touch - 1].presence
    return { channel: 'whatsapp', source: 'ai', template: nil } unless name

    { channel: 'whatsapp', source: 'template', template: name, text: template_text(name) }
  end

  def template_text(name)
    template = Array(@inbox.channel.try(:message_templates)).find { |t| t['name'] == name }
    body = Array(template&.dig('components')).find { |c| c['type'] == 'BODY' }&.dig('text')
    return nil if body.blank?

    fill_template(body, name)
  end

  # Las variables con los datos del contacto, como al mandarla (Whatsapp::TemplateParamsProcessor).
  def fill_template(body, name)
    tracking = ContactTracking.new(account: @campaign.account, contact: @contact, inbox: @inbox, tracking_template: @seller,
                                   whatsapp_templates: [name], objective: @seller&.objective)
    params = Array(Whatsapp::TemplateParamsProcessor.new(tracking, name).process[:parameters])
    params.each_with_index.reduce(body) do |text, (param, index)|
      variable = param[:parameter_name] ? /\{\{\s*#{Regexp.escape(param[:parameter_name])}\s*\}\}/ : "{{#{index + 1}}}"
      param[:text].present? ? text.gsub(variable) { param[:text] } : text
    end
  rescue StandardError => e
    Rails.logger.warn("[Motor2Simulation] plantilla #{name}: #{e.message}")
    body
  end

  def function
    @function ||= @seller && Motor2::Config.new(@seller, answers: TrackingCampaigns::Motor2Brief.seller_answers(@campaign)).function
  end

  # «Le interesa» también manda los de «cuando muestre interés».
  def interest_files
    config = Motor2::Config.new(@seller, campaign: @campaign)
    Motor2::Skills::Files.with_rule(config, 'interest', config.attachments).first(Motor2::Skills::Files::MAX_PER_MESSAGE)
  end

  def outcomes
    return [] unless function.respond_to?(:survey?)

    list = [interested.merge(files: interest_files), { kind: 'discarded' }, { kind: 'handoff', to: person_name(function.handoff_target) }]
    list << { kind: 'later' } unless function.survey?
    list << { kind: 'done' } if function.survey? || function.invite?
    list << { kind: 'no_reply', attempts: attempts }
  end

  # Le interesa: le agenda la cita, o el relevo al agente de la bandeja o a una persona.
  def interested
    return { kind: 'appointment', to: user_names(function.appointment_user_ids) } if function.appointment?
    return { kind: 'relay_person', to: person_name(function.handoff_target), board: @campaign.auto_handoff? } if function.relay_to_person?

    agent = Motor2::Relay.next_agent(RelayTracking.new(@seller&.id), RelayConversation.new(@campaign.account_id, @inbox&.id, @contact))
    return { kind: 'relay_agent', to: agent.name } if agent

    { kind: 'relay_person', to: person_name(function.handoff_target), board: @campaign.auto_handoff? }
  end

  # Lo mínimo que Motor2::Relay.next_agent pregunta, sin seguimiento ni conversación de verdad.
  RelayTracking = Struct.new(:tracking_template_id)
  RelayConversation = Struct.new(:account_id, :inbox_id, :contact)

  def user_names(ids) = @campaign.account.users.where(id: ids).pluck(:name).join(', ').presence

  def person_name(target)
    user = @campaign.account.users.find_by(id: target[:user_id]) if target[:user_id].present?
    team = @campaign.account.teams.find_by(id: target[:team_id]) if target[:team_id].present?
    [user&.name, team&.name].compact.join(' · ').presence
  end

  def warnings
    list = []
    list << { kind: 'no_address' } if address.blank?
    list << { kind: 'opted_out' } if @contact.persisted? && @contact.opted_out?
    missing = touches.select { |t| t[:channel] == 'whatsapp' && t[:source] == 'ai' }.pluck(:n)
    list << { kind: 'whatsapp_no_template', touches: missing } if missing.any?
    list
  end
end
