# Visitas — la visita de una tarea agendada, con la misma forma que una orden en «Mi ruta».
class Field::AgendaVisitSerializer
  def initialize(meeting)
    @meeting = meeting
  end

  def summary
    contact = @meeting.client_contact
    ticket = @meeting.case_ticket
    { kind: 'visit', id: ticket&.id, folio: ticket&.folio, title: @meeting.title, status: @meeting.status,
      work_address: @meeting.location, state: state,
      contact: contact && { id: contact.id, name: contact.name, phone_number: contact.phone_number },
      organization: @meeting.client_organization&.name,
      meeting: { id: @meeting.id, starts_at: @meeting.starts_at, ends_at: @meeting.ends_at } }
  end

  def as_json(*)
    summary.merge(description: @meeting.description, on_my_way_at: @meeting.on_my_way_at, arrived_at: @meeting.arrived_at,
                  arrival_location: @meeting.arrival_location)
  end

  private

  # pending → on_the_way → working → done
  def state
    return 'done' if @meeting.concluded?
    return 'working' if @meeting.arrived_at

    @meeting.on_my_way_at ? 'on_the_way' : 'pending'
  end
end
