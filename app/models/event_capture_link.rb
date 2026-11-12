# frozen_string_literal: true

# Eventos — enlace para captar en la expo «acercando el celular» (etiqueta NFC).
# Es un wa.me al WhatsApp de la bandeja con el mensaje ya escrito y un código («Ref XXXXXX»).
# Quien escribe con ese código queda en el evento como «asistió», con la etiqueta del
# evento y, si el enlace es de un vendedor, asignado a él (Events::CaptureMatcher).
class EventCaptureLink < ApplicationRecord
  CODE_CHARS = %w[A C D E F G H J K L M N P Q R T U V W X Y 3 4 6 7 9].freeze # sin 0/O, 1/I, 2/Z, 5/S, 8/B
  CODE_LENGTH = 6
  CODE_PATTERN = /\bref\W{0,2}([A-Z0-9]{#{CODE_LENGTH}})\b/i

  belongs_to :account
  belongs_to :event
  belongs_to :inbox
  belongs_to :user, optional: true

  before_validation :assign_code, on: :create
  before_validation :ensure_code_in_message

  validates :message, presence: true, length: { maximum: 500 }
  validates :code, presence: true, uniqueness: true
  validate :whatsapp_inbox

  # El código de un mensaje entrante («… Ref K7MXQA»), o nil.
  def self.code_in(text)
    text.to_s[CODE_PATTERN, 1]&.upcase
  end

  def phone_digits
    inbox.channel.try(:phone_number).to_s.gsub(/\D/, '')
  end

  # Lo que se graba en la etiqueta NFC.
  def url
    "https://wa.me/#{phone_digits}?text=#{ERB::Util.url_encode(message)}"
  end

  private

  def assign_code
    self.code ||= loop do
      candidate = Array.new(CODE_LENGTH) { CODE_CHARS.sample }.join
      break candidate unless self.class.exists?(code: candidate)
    end
  end

  def ensure_code_in_message
    return if message.blank? || code.blank? || self.class.code_in(message) == code

    self.message = "#{message.strip} (Ref #{code})"
  end

  def whatsapp_inbox
    return if inbox.nil?
    return errors.add(:inbox, 'debe ser de WhatsApp') unless inbox.channel.is_a?(Channel::Whatsapp)

    errors.add(:inbox, 'no tiene número de WhatsApp') if phone_digits.blank?
  end
end
