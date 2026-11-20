# frozen_string_literal: true

# Motor 2.0 — el texto de un mensaje del cliente como lo lee el agente: lo que escribió, el texto de sus
# documentos (ContactTrackings::AttachmentText: PDF, Excel, Word) y, solo en el 2.0, lo que dice su nota
# de voz y lo que muestra su imagen (Motor2::MediaReader). Lo usa Motor2::Prompt.history.
module Motor2::MessageText
  module_function

  def call(message)
    base = ContactTrackings::AttachmentText.message_text(message)
    return base unless message.incoming?

    media = message.attachments.filter_map { |attachment| Motor2::MediaReader.read(message.account, attachment) }
    [base.presence, *media].compact.join("\n\n")
  end
end
