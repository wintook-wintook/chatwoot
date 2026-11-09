# frozen_string_literal: true

# Asistente (Dali) — hace lo que el usuario confirmó. El usuario pudo cambiar los
# datos en la tarjeta, así que se vuelve a validar todo con sus permisos (por eso se
# reusa Assistant::Tools#target_for) y se usan las mismas piezas que las pantallas:
# nota del caso o del contacto, tarea (con caso o suelta), tarea agendada
# (AgendaItems::Creator, que la manda a Google) y mensaje programado.
# Lo que toca la bitácora del caso queda marcado «vía asistente» (Current.via_assistant).
class Assistant::Executor
  include Assistant::DelegationRunner # D3
  include Assistant::CaseRunner # D4
  include Assistant::QuoteRunner # cotizaciones
  include Assistant::ConversationRunner # contestar conversaciones
  include Assistant::FieldRunner # trabajo en campo
  include Assistant::EventRunner # NFC en la expo
  include Assistant::ClientTaskRunner # tareas con el cliente
  include Assistant::CancelRunner # cancelar con motivo
  include Assistant::ConvertRunner # tarea ↔ tarea agendada

  class Refused < StandardError; end

  FROZEN = 'El caso está cerrado: no se puede modificar.'

  def initialize(account:, user:, grant:, zone:)
    @account = account
    @user = user
    @grant = grant
    @zone = zone
    @tools = Assistant::Tools.new(account: account, user: user, grant: grant, zone: zone)
  end

  # → { 'label' => qué se hizo, 'path' => dónde verlo }
  def call(type, payload)
    payload = payload.to_h.stringify_keys
    Current.via_assistant = true
    public_send("run_#{type}", payload)
  rescue ActiveRecord::RecordNotFound
    raise Refused, 'No encontré ese registro o no tienes acceso.'
  ensure
    Current.via_assistant = nil
  end

  def run_note(payload)
    content = payload['content'].to_s.strip
    raise Refused, 'Falta el texto de la nota.' if content.blank?

    if payload['case_id'].present?
      ticket = @tools.cases.find(payload['case_id'])
      ticket.case_events.create!(account: @account, event_type: :internal_note, origin: :agent, actor: @user,
                                 payload: { content: content })
      return done("Nota en #{ticket.folio}", case_path(ticket))
    end
    contact = @tools.contacts.find(payload['contact_id'])
    Note.create!(account: @account, contact: contact, user: @user, content: content)
    done("Nota en #{contact.name}", "#{base}/contacts/#{contact.id}")
  end

  def run_task(payload)
    raise Refused, 'Falta el título de la tarea.' if payload['title'].blank?

    ticket = payload['case_id'].present? ? writable_case(payload['case_id']) : nil
    task = if ticket
             ticket.case_tasks.create!(task_attrs(payload).merge(position: ticket.case_tasks.count))
           else
             CaseTask.create!(task_attrs(payload).merge(client(payload)))
           end
    done("Tarea «#{task.title}»", ticket ? case_path(ticket) : "#{base}/tickets/tasks")
  end

  def run_meeting(payload)
    ticket = payload['case_id'].present? ? writable_case(payload['case_id']) : nil
    meeting = AgendaItems::Creator.new(account: @account, user: @user, attrs: meeting_attrs(payload),
                                       client: ticket ? { case_ticket: ticket } : client(payload)).call
    done("Tarea agendada «#{meeting.title}»", ticket ? case_path(ticket) : "#{base}/tickets/tasks")
  end

  def run_scheduled_message(payload)
    conversation = @tools.find_conversation(payload['conversation_id'])
    send_at = time(payload['send_at'])
    raise Refused, 'La fecha de envío ya pasó.' if send_at.nil? || send_at < Time.current
    raise Refused, 'Falta el texto del mensaje.' if payload['content'].blank?

    @account.scheduled_messages.create!(conversation: conversation, user: @user, content: payload['content'].to_s,
                                        scheduled_at: send_at, message_type: 'outgoing')
    done("Mensaje programado para #{send_at.in_time_zone(@zone).strftime('%d/%m %H:%M')}",
         "#{base}/conversations/#{conversation.display_id}")
  rescue ArgumentError => e
    raise Refused, e.message
  end

  # El borrador no se ejecuta: el usuario lo copió.
  def run_draft(_payload)
    done('Borrador copiado', nil)
  end

  private

  def task_attrs(payload)
    { account: @account, requester: @user, title: payload['title'].to_s.first(255),
      description: payload['description'].presence, due_at: time(payload['due_at']),
      assignee: @account.users.find_by(id: payload['assignee_id']) || @user }
  end

  def meeting_attrs(payload)
    starts = time(payload['starts_at'])
    raise Refused, 'Falta la fecha y hora.' unless starts

    ends = time(payload['ends_at']) || (starts + 30.minutes)
    { title: payload['title'].to_s.first(255), description: payload['description'].presence,
      location: payload['location'].presence, is_visit: payload['is_visit'] == true,
      starts_at: starts, ends_at: [ends, starts + 5.minutes].max }
  end

  def writable_case(id)
    ticket = @tools.cases.find(id)
    raise Refused, FROZEN if ticket.frozen_for_edit?

    ticket
  end

  def client(payload)
    { contact: (@tools.contacts.find(payload['contact_id']) if payload['contact_id'].present?),
      organization: (@account.organizations.find(payload['organization_id']) if payload['organization_id'].present?) }
  end

  def time(value)
    value.present? ? Time.zone.parse(value.to_s) : nil
  rescue ArgumentError
    nil
  end

  def base = "/app/accounts/#{@account.id}"
  def case_path(ticket) = "#{base}/tickets/#{ticket.id}"
  def done(label, path) = { 'label' => label, 'path' => path }
end
