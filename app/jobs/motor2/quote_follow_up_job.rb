# frozen_string_literal: true

# Motor 2.0 — a los N días de mandarle la cotización que armó el agente (Motor2::Skills::Quote, en los dos modos: en
# borrador cuenta desde que el vendedor la manda): si sigue enviada y el cliente no ha escrito desde entonces, le
# pregunta si pudo revisarla y avisa al vendedor. Dentro de las 24 h, texto libre; pasadas, con la plantilla PROPIA de
# cotizaciones (no la del seguimiento). Si no se pudo, la nota al vendedor lo dice.
class Motor2::QuoteFollowUpJob < ApplicationJob
  queue_as :default

  # Al quedar enviada (Quote after_commit): el agente que la armó la tiene en su memoria (state['quote']).
  def self.schedule(quote)
    tracking = ContactTracking.where(account_id: quote.account_id).where("motor2_state -> 'quote' ->> 'id' = ?", quote.id.to_s)
                              .order(id: :desc).first
    function = tracking && Motor2::Config.for(tracking).function
    return unless function.respond_to?(:quote_follow?) && function.quote_follow?

    set(wait: function.quote_follow_days.days).perform_later(tracking.id, quote.id)
  end

  def perform(tracking_id, quote_id)
    tracking = ContactTracking.find_by(id: tracking_id)
    quote = Quote.find_by(id: quote_id)
    return unless tracking&.conversation && quote&.status == 'sent' && !answered?(tracking, quote)

    config = Motor2::Config.for(tracking)
    message = Motor2::VoiceText.call(config, text(tracking, quote))
    sent = Motor2::LateMessage.deliver(tracking, message, template: config.function.try(:quote_template))
    Motor2::Delivery.note(tracking, tracking.conversation, note(quote, sent))
  end

  private

  # El cliente ya escribió después de recibirla: la plática sigue, no hace falta preguntarle.
  def answered?(tracking, quote)
    tracking.conversation.messages.incoming.exists?(['created_at > ?', quote.sent_at || quote.updated_at])
  end

  def note(quote, sent)
    who = quote.assignee ? "#{TrackingCampaigns::HandOff.mention(quote.assignee)} " : ''
    return "🧾 #{who}le preguntamos por la cotización #{quote.folio}." if sent

    "⚠️ #{who}no se le pudo preguntar por la cotización #{quote.folio}: ya pasaron 24 h desde su último mensaje y el " \
      'agente no tiene plantilla de cotizaciones (o no se pudo usar). Escríbele tú o elige una en la pestaña Cotizaciones.'
  end

  def text(tracking, quote)
    name = tracking.contact&.name.to_s.split.first
    hello = name.present? && !name.match?(/\A[+\d]/) ? "¡Hola #{name}!" : '¡Hola!'
    "#{hello} ¿Pudiste revisar la cotización #{quote.folio}? Si tienes alguna duda, aquí estoy."
  end
end
