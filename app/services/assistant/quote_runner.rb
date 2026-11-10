# frozen_string_literal: true

# Asistente (Dali) — hace lo confirmado de cotizaciones con las mismas piezas que la
# pantalla: Quotes::Builder (folio, vigencia, moneda y oportunidad de la empresa) para
# crearla en borrador y Quotes::Delivery para mandarla. Las partidas se vuelven a armar
# desde el payload (el usuario pudo cambiar cantidades o precios en la tarjeta).
# Se incluye en Assistant::Executor.
module Assistant::QuoteRunner
  def run_create_quote(payload)
    raise Assistant::Executor::Refused, 'No tienes permiso para crear cotizaciones (Ventas).' unless @grant.writable?(:sales)

    contact = @tools.contacts.find(payload['contact_id'])
    items = @tools.quote_items(payload['items'])
    quote = Quote.transaction { build_assistant_quote(contact, items, payload) }
    done("Cotización #{quote.folio} creada en borrador", "#{base}/tickets/quotes/#{quote.id}")
  rescue ArgumentError, Quotes::Builder::Error => e
    raise Assistant::Executor::Refused, e.message
  end

  def run_send_quote(payload)
    quote = @grant.quotes(@account.quotes).find(payload['quote_id'])
    raise Assistant::Executor::Refused, "La cotización #{quote.folio} ya no está abierta." unless quote.live?

    Quotes::Delivery.new(quote, @user).deliver!
    done("Cotización #{quote.folio} enviada a #{quote.contact.name}", "#{base}/tickets/quotes/#{quote.id}")
  rescue Quotes::Delivery::Error => e
    raise Assistant::Executor::Refused, e.message
  end

  private

  def build_assistant_quote(contact, items, payload)
    opportunity = payload['opportunity_id'].present? ? @tools.cases.commercial.find(payload['opportunity_id']) : nil
    quote = Quotes::Builder.new(@account, @user).create!(
      { contact_id: contact.id, currency: payload['currency'].presence, notes: payload['notes'].presence, opportunity: opportunity },
      create_opportunity: ActiveModel::Type::Boolean.new.cast(payload['create_opportunity'])
    )
    items.each_with_index do |item, index|
      quote.items.create!(item.compact.merge('account_id' => @account.id, 'position' => index))
    end
    quote.recalculate!
    quote
  end
end
