# frozen_string_literal: true

# Eventos — alguien escribió por WhatsApp con el enlace de una etiqueta NFC del evento
# («… Ref K7MXQA»). Lo liga al evento como «asistió» (fuente nfc), le pone la etiqueta del
# evento a la conversación y, si el enlace es de un vendedor y nadie la atiende, se la asigna.
# Solo el primer mensaje entrante de la conversación cuenta (si vuelve a escribir no duplica).
class Events::CaptureMatcher
  def initialize(message)
    @message = message
  end

  def call
    link = capture_link
    return unless link

    attendee = attend(link)
    @message.conversation.add_labels([label_for(link.event)])
    assign(link)
    link.increment!(:captures_count) # rubocop:disable Rails/SkipsModelValidations
    attendee
  end

  def self.label_for(event)
    "evento-#{event.name.parameterize}".first(60)
  end

  private

  def capture_link
    return unless @message.incoming? && @message.conversation&.contact

    code = EventCaptureLink.code_in(@message.content)
    return unless code
    return if earlier_incoming?

    EventCaptureLink.includes(:event).find_by(code: code, account_id: @message.account_id, inbox_id: @message.inbox_id)
  end

  def earlier_incoming?
    @message.conversation.messages.incoming.exists?(['id < ?', @message.id])
  end

  def attend(link)
    attendee = link.event.attendees.find_or_initialize_by(contact: @message.conversation.contact)
    attendee.account_id ||= link.account_id
    attendee.source = 'nfc' if attendee.new_record?
    attendee.status = :attended unless attendee.attended?
    attendee.save!
    attendee
  end

  def label_for(event) = self.class.label_for(event)

  def assign(link)
    conversation = @message.conversation
    return if link.user.nil? || conversation.assignee_id.present?
    return unless link.account.users.exists?(link.user_id)

    conversation.update!(assignee: link.user)
  end
end
