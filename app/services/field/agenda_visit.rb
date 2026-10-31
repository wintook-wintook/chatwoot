# Visitas — la visita de una tarea agendada (el vendedor, o cualquiera sin orden de
# trabajo): Voy en camino y Llegué con su ubicación. Termina con el reporte de cierre.
class Field::AgendaVisit
  def initialize(meeting, user)
    @meeting = meeting
    @user = user
  end

  # El aviso al cliente sale si tiene conversación; si no, solo queda la hora.
  def on_my_way!(eta_minutes)
    eta = (Time.current + eta_minutes.clamp(5, 240).minutes).in_time_zone.strftime('%H:%M')
    @meeting.update!(on_my_way_at: Time.current)
    conversation = customer_conversation
    return unless conversation

    Messages::MessageBuilder.new(@user, conversation, { content: message(eta), message_type: 'outgoing' }).perform
  end

  # Solo la primera llegada cuenta; sin permiso de ubicación se llega sin coordenadas.
  def arrive!(location, at: Time.current)
    return if @meeting.arrived_at

    @meeting.update!(arrived_at: at, arrival_location: location)
  end

  private

  def message(eta)
    name = @meeting.client_contact&.name.to_s.split.first.to_s
    I18n.t('field.on_my_way_visit', name: name, technician: @user.name, eta: eta)
  end

  def customer_conversation
    contact = @meeting.client_contact
    return if contact.nil?

    @meeting.case_ticket&.conversation || @meeting.account.conversations.where(contact_id: contact.id).order(last_activity_at: :desc).first
  end
end
