# frozen_string_literal: true

# Tareas con el cliente — le avisa al cliente por la conversación del caso (o la más
# reciente de su contacto) con el enlace de su portal: tarea nueva, regresada o por vencer.
# Solo si la conversación deja escribir libre (ventana de 24 h de WhatsApp abierta); si no,
# no manda nada y dice por qué, para que lo hagan con una plantilla o por otro medio.
#   ClientTasks::Notifier.new(task, user).call(:assigned | :returned | :due_soon | :overdue)
#   → { sent: true } | { sent: false, reason: 'no_conversation' | 'window_closed' | 'no_owner' }
class ClientTasks::Notifier
  KINDS = %i[assigned returned due_soon overdue].freeze

  def initialize(task, user = nil)
    @task = task
    @ticket = task.case_ticket
    @user = user
  end

  def call(kind)
    link = portal_link
    return { sent: false, reason: 'no_owner' } unless link

    conversation = customer_conversation
    return { sent: false, reason: 'no_conversation' } unless conversation
    return { sent: false, reason: 'window_closed' } unless conversation.can_reply?

    Messages::MessageBuilder.new(sender(conversation), conversation, { content: text(kind, link), message_type: 'outgoing' }).perform
    { sent: true }
  end

  private

  def portal_link
    if @ticket.organization_id
      ClientPortalLink.for!(account: @ticket.account, organization: @ticket.organization, user: @user)
    elsif @ticket.contact
      ClientPortalLink.for!(account: @ticket.account, contact: @ticket.contact, user: @user)
    end
  end

  def customer_conversation
    return @ticket.conversation if @ticket.conversation
    return if @ticket.contact_id.nil?

    @ticket.account.conversations.where(contact_id: @ticket.contact_id).order(last_activity_at: :desc).first
  end

  # Quien escribe: el usuario que lo hizo o, en los recordatorios, el responsable del caso.
  def sender(conversation)
    @user || @ticket.assignee || conversation.assignee
  end

  def text(kind, link)
    I18n.with_locale(@ticket.account.locale.presence || I18n.default_locale) do
      due = @task.due_at && I18n.t('client_portal.notify.due', date: @task.due_at.in_time_zone.strftime('%d/%m/%Y'))
      I18n.t("client_portal.notify.#{kind}", name: @ticket.contact&.name.to_s.split.first.to_s, title: @task.title,
                                             due: due.to_s, url: link.url)
    end
  end
end
