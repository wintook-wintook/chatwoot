# frozen_string_literal: true

# Cobranza — a quién le toca su recordatorio hoy (lo corre Receivables::OutreachJob a la hora del agente). Cada toque es un
# seguimiento del agente (ContactTracking) que sale con el envío de siempre (ContactTrackingJob): en WhatsApp con la
# plantilla de su etapa; en correo, o con la ventana de 24 h abierta, con el resumen que arma Motor2::CollectionsTouch.
#
# Le toca si: está ligado, tiene a dónde escribirle, debe al menos el mínimo (sin aclaración ni «ya pagué»), no tiene una
# promesa vigente, no lo está atendiendo ya el agente o una persona, y
#   - antes de vencer: una factura vence en los próximos remind_before_days y no se le avisó desde entonces;
#   - vencido: nunca se le escribió o ya pasaron every_days.
# Sin plantilla para su etapa (WhatsApp) no se le escribe: se cuenta en «sin plantilla».
#
#   Receivables::Outreach.new(template).call → { sent:, skipped: { motivo => n } }
class Receivables::Outreach
  LIVE = %w[pending scheduled active paused].freeze

  def initialize(template, now: Time.current)
    @template = template
    @account = template.account
    @inbox = template.inbox
    @function = Motor2::Config.new(template).function
    @now = now
    @today = now.to_date
    @skipped = Hash.new(0)
  end

  def call
    return { sent: 0, skipped: { 'sin canal' => 1 } } unless channel?

    sent = 0
    room = limit
    candidates.each do |customer|
      break if sent >= room

      sent += 1 if consider(customer)
    end
    { sent: sent, skipped: @skipped.to_h }
  end

  private

  def setting(name) = @function.setting(name)

  def channel? = @inbox.present? && (@inbox.whatsapp? || @inbox.email?)

  # true si se le escribió.
  def consider(customer)
    reason = skip_reason(customer)
    return send_touch(customer) unless reason

    @skipped[reason] += 1
    false
  end

  # Los de hoy cuentan para el tope del día.
  def limit
    already = @account.receivable_customers.where(last_contacted_at: @now.beginning_of_day..@now).count
    [setting(:max_per_day).to_i - already, 0].max
  end

  def candidates
    @account.receivable_customers.linked.where.not(contact_id: nil).includes(:contact)
            .where(id: Receivable.collectable.where(account_id: @account.id).select(:receivable_customer_id))
            .order(Arel.sql('last_contacted_at ASC NULLS FIRST'))
  end

  def skip_reason(customer)
    contact = customer.contact
    return 'sin WhatsApp ni correo' unless reachable?(contact)
    return 'se dio de baja' if contact.opted_out?

    @summary = Receivables::Summary.new(customer, today: @today)
    return 'debe menos del mínimo' if @summary.total < setting(:min_balance).to_f

    timing_reason(customer, contact)
  end

  def timing_reason(customer, contact)
    return 'promesa vigente' if Receivables::Promises.active?(customer, today: @today)
    return 'ya lo están atendiendo' if busy?(contact)
    return 'todavía no le toca' unless due?(customer)

    'sin plantilla para su etapa' if @inbox.whatsapp? && @function.template_for(@summary.stage).nil?
  end

  def reachable?(contact) = @inbox.whatsapp? ? contact.phone_number.present? : contact.email.present? && !contact.email_bounced?

  def busy?(contact)
    ContactTracking.exists?(contact_id: contact.id, inbox_id: @inbox.id, status: LIVE)
  end

  def due?(customer)
    return preventive_due?(customer) if @summary.stage == 'preventive'

    customer.last_contacted_at.nil? || customer.last_contacted_at <= setting(:every_days).to_i.days.ago(@now)
  end

  # Antes de vencer: solo si una factura vence dentro de los días de aviso y no se le avisó desde que entró a esos días.
  def preventive_due?(customer)
    days = setting(:remind_before_days).to_i
    return false if days.zero?

    next_due = @summary.invoices.pluck(:due_on).min
    return false unless next_due && (next_due - @today).to_i <= days

    customer.last_contacted_at.nil? || customer.last_contacted_at.to_date < next_due - days
  end

  def send_touch(customer)
    contact = customer.contact
    contact.update!(custom_attributes: contact.custom_attributes.to_h.merge(@summary.template_attributes))
    tracking_id = insert_tracking(customer, contact)
    ContactTrackingJob.perform_later(tracking_id)
    customer.update_columns(last_contacted_at: @now, touches: customer.touches + 1, updated_at: @now) # rubocop:disable Rails/SkipsModelValidations
    true
  rescue StandardError => e
    Rails.logger.error("[Receivables::Outreach] cliente #{customer.id}: #{e.class}: #{e.message}")
    @skipped['error'] += 1
    false
  end

  # Como TrackingCampaigns::TrackingBuilder: insert! (la validación de scheduled_for en el pasado no aplica a «ahora»).
  def insert_tracking(customer, contact)
    conversation_id = contact.conversations.where(inbox_id: @inbox.id).order(last_activity_at: :desc).pick(:id)
    template = @function.template_for(@summary.stage) if @inbox.whatsapp?
    attrs = base_attributes(contact, conversation_id).merge(
      whatsapp_templates: template ? [template] : [],
      motor2_state: { 'follow_up' => true, 'collections' => { 'customer_id' => customer.id, 'stage' => @summary.stage } }
    )
    ContactTracking.insert!(attrs, returning: [:id]).rows.first.first # rubocop:disable Rails/SkipsModelValidations
  end

  def base_attributes(contact, conversation_id)
    { account_id: @account.id, contact_id: contact.id, inbox_id: @inbox.id, conversation_id: conversation_id,
      tracking_template_id: @template.id, objective: @template.objective, scheduled_for: @now, max_attempts: 1, attempt_count: 0,
      retry_interval_value: 1, retry_interval_unit: 'days', ai_context: @template.ai_context, complementary_prompt: nil,
      keyword_actions: [], calendar_integration_ids: [], calendar_event_duration: 30, response_adjustments_count: 0,
      status: 'pending', created_at: @now, updated_at: @now }
  end
end
