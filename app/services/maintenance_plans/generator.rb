# Plan-Trabajo-Campo R4 — genera la orden de trabajo de un mantenimiento
# recurrente y adelanta la siguiente fecha. Si el plan pide avisar, le escribe al
# cliente por su conversación más reciente. No duplica: si el plan ya tiene una
# orden abierta, solo adelanta la fecha.
class MaintenancePlans::Generator
  def initialize(plan)
    @plan = plan
  end

  def call
    order = MaintenancePlan.transaction do
      (open_order || create_order).tap { @plan.advance! }
    end
    notify(order) if @plan.notify_customer && order.previously_new_record?
    order
  end

  private

  def open_order
    @plan.case_tickets.where.not(status: %w[closed cancelled resolved validating]).first
  end

  def create_order
    CaseTicket.create!(
      account: @plan.account, contact: @plan.contact, case_type: @plan.case_type, origin: :manual,
      title: title, description: @plan.notes, customer_asset: @plan.customer_asset, maintenance_plan: @plan,
      assignee: @plan.assignee, assignee_type: @plan.assignee ? :agent : :bot,
      work_address: @plan.customer_asset&.location, due_at: @plan.next_due_on.end_of_day
    )
  end

  def title
    asset = @plan.customer_asset
    [@plan.title, asset&.name].compact.join(' · ').truncate(255)
  end

  def notify(order)
    conversation = @plan.account.conversations.where(contact_id: @plan.contact_id).order(last_activity_at: :desc).first
    return unless conversation

    content = I18n.t('maintenance_plans.customer_notice', name: @plan.contact.name.to_s.split.first || '',
                                                          title: @plan.title, date: @plan.next_due_on.strftime('%d/%m/%Y'),
                                                          folio: order.folio, url: Field::Messages.portal_url(order))
    Messages::MessageBuilder.new(nil, conversation, { content: content, message_type: 'outgoing' }).perform
  rescue StandardError => e
    Rails.logger.info "[MaintenancePlan] #{@plan.id}: no se avisó al cliente (#{e.message})"
  end
end
