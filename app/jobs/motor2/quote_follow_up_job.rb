# frozen_string_literal: true

# Motor 2.0 — a los N días de mandarle la cotización (Motor2::Skills::Quote, modo «la manda»): si sigue sin respuesta
# (enviada, ni aceptada ni rechazada), le pregunta si pudo revisarla y avisa al vendedor.
class Motor2::QuoteFollowUpJob < ApplicationJob
  queue_as :default

  def perform(tracking_id, quote_id)
    tracking = ContactTracking.find_by(id: tracking_id)
    quote = Quote.find_by(id: quote_id)
    return unless tracking&.conversation && quote&.status == 'sent'

    message = Motor2::VoiceText.call(Motor2::Config.new(tracking.tracking_template), text(tracking, quote))
    Motor2::LateMessage.deliver(tracking, message, template: template(tracking))
    who = quote.assignee ? "#{TrackingCampaigns::HandOff.mention(quote.assignee)} " : ''
    Motor2::Delivery.note(tracking, tracking.conversation, "🧾 #{who}le preguntamos por la cotización #{quote.folio}.")
  end

  private

  def text(tracking, quote)
    name = tracking.contact&.name.to_s.split.first
    hello = name.present? && !name.match?(/\A[+\d]/) ? "¡Hola #{name}!" : '¡Hola!'
    "#{hello} ¿Pudiste revisar la cotización #{quote.folio}? Si tienes alguna duda, aquí estoy."
  end

  # Pasadas las 24 h: la primera plantilla de su seguimiento.
  def template(tracking)
    Array(Motor2::Config.new(tracking.tracking_template).function.try(:follow_up).to_h[:templates]).first
  end
end
