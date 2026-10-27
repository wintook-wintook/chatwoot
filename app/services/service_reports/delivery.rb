# Plan-Trabajo-Campo R1 — manda al cliente el enlace del reporte de servicio por la
# conversación de la orden (o la más reciente del contacto) y deja la marca.
class ServiceReports::Delivery
  Error = Class.new(StandardError)

  def initialize(ticket, user)
    @ticket = ticket
    @user = user
  end

  def deliver!
    conversation = target_conversation
    raise Error, I18n.t('service_reports.errors.no_conversation') unless conversation

    message = Messages::MessageBuilder.new(@user, conversation, { content: content, message_type: 'outgoing' }).perform
    @ticket.update_column(:report_sent_at, Time.current) # rubocop:disable Rails/SkipsModelValidations
    message
  rescue ActiveRecord::RecordInvalid => e
    raise Error, e.record.errors.full_messages.join(', ')
  end

  def self.public_url(ticket)
    "#{ENV.fetch('FRONTEND_URL', '')}/reporte/#{ticket.ensure_report_token!}"
  end

  private

  def target_conversation
    return @ticket.conversation if @ticket.conversation
    return if @ticket.contact_id.nil?

    @ticket.account.conversations.where(contact_id: @ticket.contact_id).order(last_activity_at: :desc).first
  end

  def content
    I18n.t('service_reports.delivery_message', name: @ticket.contact&.name.to_s.split.first || '',
                                               folio: @ticket.folio, url: self.class.public_url(@ticket))
  end
end
