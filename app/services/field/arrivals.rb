# Visitas — dónde y cuándo llegó cada quien, técnicos y vendedores: las llegadas de las
# visitas y las de las órdenes (su entrada de horas guarda la ubicación).
class Field::Arrivals
  LIMIT = 500

  def initialize(account, user_id: nil, from: nil, to: nil)
    @account = account
    @user_id = user_id
    @from = from
    @to = to
  end

  def rows
    (visits + orders).sort_by { |row| row[:at] }.reverse.first(LIMIT)
  end

  private

  def range
    (@from || 30.days.ago)..(@to || Time.current)
  end

  def visits
    scope = @account.case_meetings.where(arrived_at: range).includes(:organizer, :contact, :organization, case_ticket: %i[contact organization])
    scope = scope.where(organizer_id: @user_id) if @user_id
    scope.order(arrived_at: :desc).limit(LIMIT).map do |meeting|
      { kind: 'visit', at: meeting.arrived_at, user: meeting.organizer&.name, title: meeting.title, folio: meeting.case_ticket&.folio,
        contact: meeting.client_contact&.name, organization: meeting.client_organization&.name }.merge(coordinates(meeting.arrival_location))
    end
  end

  def orders
    scope = CaseTimeEntry.visit.where(account_id: @account.id, started_at: range)
                         .includes(:user, case_ticket: %i[contact organization])
    scope = scope.where(user_id: @user_id) if @user_id
    scope.order(started_at: :desc).limit(LIMIT).map { |entry| order_row(entry) }
  end

  def order_row(entry)
    order = entry.case_ticket
    { kind: 'order', at: entry.started_at, user: entry.user&.name || entry.note, title: order.title, folio: order.folio,
      contact: order.contact&.name, organization: order.organization&.name }.merge(coordinates(entry.location['arrive']))
  end

  def coordinates(location)
    location = location.to_h.with_indifferent_access
    { lat: location[:lat], lng: location[:lng], accuracy: location[:accuracy] }
  end
end
