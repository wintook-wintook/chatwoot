# Plan-Trabajo-Campo R2 — mensajes del trabajo en campo:
#   · «Voy en camino» al cliente, con la hora estimada de llegada, por su conversación;
#   · «Enviar al técnico»: el enlace de la visita al WhatsApp del técnico (su
#     contacto de agente, Ajustes › Usuarios).
class Field::Messages
  Error = Class.new(StandardError)

  def initialize(order, user)
    @order = order
    @user = user
  end

  def on_my_way!(eta_minutes)
    conversation = customer_conversation
    raise Error, I18n.t('field.errors.no_conversation') unless conversation

    eta = (Time.current + eta_minutes.clamp(5, 240).minutes).in_time_zone.strftime('%H:%M')
    send_message(conversation, I18n.t('field.on_my_way', name: first_name(@order.contact&.name), technician: @user.name,
                                                         eta: eta, url: self.class.portal_url(@order)))
    @order.case_events.create!(account: @order.account, event_type: :internal_note, origin: :agent, actor: @user,
                               payload: { field: 'on_my_way', eta: eta, content: I18n.t('field.on_my_way_note', eta: eta) })
  end

  def to_technician!
    technician = @order.assignee
    raise Error, I18n.t('field.errors.no_technician') unless technician

    contact = @order.account.account_users.find_by(user: technician)&.agent_contact
    conversation = contact && @order.account.conversations.where(contact_id: contact.id).order(last_activity_at: :desc).first
    raise Error, I18n.t('field.errors.no_technician_contact', name: technician.name) unless conversation

    send_message(conversation, I18n.t('field.to_technician', name: first_name(technician.name), folio: @order.folio,
                                                             title: @order.title, url: visit_url))
  end

  # Plan-Trabajo-Campo R5 — portal del cliente de su orden (mismo token que el reporte).
  def self.portal_url(order)
    "#{ENV.fetch('FRONTEND_URL', '')}/servicio/#{order.ensure_report_token!}"
  end

  private

  def customer_conversation
    return @order.conversation if @order.conversation
    return if @order.contact_id.nil?

    @order.account.conversations.where(contact_id: @order.contact_id).order(last_activity_at: :desc).first
  end

  def send_message(conversation, content)
    Messages::MessageBuilder.new(@user, conversation, { content: content, message_type: 'outgoing' }).perform
  end

  def first_name(name)
    name.to_s.split.first || ''
  end

  def visit_url
    "#{ENV.fetch('FRONTEND_URL', '')}/app/accounts/#{@order.account_id}/campo/visita/#{@order.id}"
  end
end
