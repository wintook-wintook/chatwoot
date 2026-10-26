# Plan-Trabajo-Campo R2 — una orden de trabajo vista desde el celular del técnico.
class Field::VisitSerializer
  def initialize(order, user)
    @order = order
    @user = user
  end

  def summary
    contact = @order.contact
    {
      id: @order.id, folio: @order.folio, title: @order.title, status: @order.status,
      work_address: @order.work_address, on_site: @order.on_site_effective,
      contact: contact && { id: contact.id, name: contact.name, phone_number: contact.phone_number },
      state: state
    }
  end

  def as_json(*)
    summary.merge(
      description: @order.description, received_by: @order.received_by, received_at: @order.received_at,
      conformity_note: @order.conformity_note, has_signature: @order.conformity_signature.present?,
      on_my_way_at: on_my_way_at, visit_entry: visit_entry, items: items,
      report: ServiceReports::Serializer.new(@order, user: @user).as_json
    )
  end

  private

  # pending → on_the_way → working → done
  def state
    return 'done' if ServiceReportable::COMPLETION_STATUSES.include?(@order.status)
    return 'working' if open_visit_entry

    on_my_way_at ? 'on_the_way' : 'pending'
  end

  def open_visit_entry
    @open_visit_entry ||= @order.time_entries.visit.running.find_by(user_id: @user&.id)
  end

  def visit_entry
    entry = open_visit_entry || @order.time_entries.visit.where(user_id: @user&.id).order(:started_at).last
    entry && { id: entry.id, started_at: entry.started_at, ended_at: entry.ended_at, location: entry.location }
  end

  def on_my_way_at
    @order.case_events.where("payload ->> 'field' = 'on_my_way'").order(:created_at).last&.created_at
  end

  def items
    @order.work_order_items.ordered.map do |item|
      { id: item.id, description: item.description, quantity: item.quantity.to_f, unit: item.unit }
    end
  end
end
