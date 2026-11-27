# frozen_string_literal: true

# «Cobranza» — lo que hace el agente de cobranza con la cartera (Motor2::Functions::Collections):
#   resumen_de_saldo   el «Resumen de saldo pendiente» tal cual (montos y fechas los pone el código)
#   registrar_promesa  «pago el viernes» → PaymentPromise (no se le cobra hasta esa fecha)
#   ya_pague           «ya pagué» → PaymentClaim con el comprobante; sus facturas dejan de cobrarse hasta que el
#                      cobrador lo valide o lo rechace
#   aclarar_factura    «esa factura está mal» → la factura en aclaración (no se cobra) y un caso para el área
# En «Probar» no se guarda nada.
class Motor2::Skills::Collections < Motor2::Skills::Base
  MAX_PROMISE_DAYS = 60

  def self.key = 'collections'

  def on? = config.skill_on?(key) && function.is_a?(Motor2::Functions::Collections)

  def tools
    [fn('resumen_de_saldo', 'El resumen de lo que debe (facturas, vencimientos y total), para mandárselo tal cual.', {}, []),
     fn('registrar_promesa', 'Dijo en qué fecha paga: registra la promesa de pago.',
        { fecha: { type: 'string', description: 'AAAA-MM-DD' }, monto: { type: 'number' }, nota: STR }, %w[fecha]),
     fn('ya_pague', 'Dice que ya pagó (de preferencia con el comprobante que mandó): lo pasa a cobranza para validarlo.',
        { monto: { type: 'number' }, nota: STR }, %w[nota]),
     fn('aclarar_factura', 'Dice que una factura está mal (no la reconoce, monto equivocado…): la pone en aclaración.',
        { folio: STR, motivo: STR }, %w[folio motivo])]
  end

  def instructions
    "- Hoy es #{Date.current.strftime('%Y-%m-%d')}: convierte «el viernes», «el 15» en fecha AAAA-MM-DD para registrar_promesa."
  end

  def call(name, args)
    case name
    when 'resumen_de_saldo' then summary
    when 'registrar_promesa' then promise(args)
    when 'ya_pague' then claim(args)
    else dispute(args)
    end
  end

  private

  def function = config.function

  def customer = @customer ||= function.customer_for(@turn.conversation)

  def summary
    return { error: 'No está en la cartera: no le des montos; pásalo al cobrador.' } unless customer

    { texto: Receivables::Summary.new(customer).text, nota: 'Mándale este resumen tal cual (puedes poner una frase antes).' }
  end

  def promise(args)
    date = Date.iso8601(args['fecha'].to_s)
    return { error: "La fecha no puede ser antes de hoy (#{Date.current})." } if date < Date.current
    return { error: "Una promesa de más de #{MAX_PROMISE_DAYS} días la decide el cobrador: pásalo." } if date > MAX_PROMISE_DAYS.days.from_now
    return { error: 'No está en la cartera.' } unless customer

    save_promise(date, args) unless test?
    @turn.decide('promise', "#{I18n.l(date, format: '%d/%m/%Y')}#{amount_text(args['monto'])}")
    { ok: true, nota: "Quedó la promesa para el #{I18n.l(date, format: '%d/%m/%Y')}: confírmasela en una frase y agradece." }
  rescue Date::Error
    { error: 'Escribe la fecha como AAAA-MM-DD.' }
  end

  def save_promise(date, args)
    customer.payment_promises.pending.update_all(status: 'broken', updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    customer.payment_promises.create!(account_id: customer.account_id, conversation_id: @turn.conversation&.id, promised_on: date,
                                      amount: args['monto'].presence, note: args['nota'].to_s.first(250).presence)
  end

  def claim(args)
    return { error: 'No está en la cartera: pásalo al cobrador.' } unless customer

    save_claim(args) unless test?
    @turn.decide('claim', "#{args['nota']}#{amount_text(args['monto'])}")
    { ok: true, nota: 'Listo: dile que cobranza revisa su comprobante y que mientras no le volveremos a cobrar esas facturas.' }
  end

  def save_claim(args)
    message = proof_message
    customer.payment_claims.create!(account_id: customer.account_id, conversation_id: @turn.conversation&.id, message_id: message&.id,
                                    amount: args['monto'].presence, note: args['nota'].to_s.first(250))
    customer.receivables.collectable.update_all(claimed_at: Time.current, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  # El último mensaje del cliente con archivo (foto o PDF del comprobante).
  def proof_message
    conversation = @turn.conversation
    conversation && conversation.messages.incoming.joins(:attachments).reorder(created_at: :desc).first
  end

  def dispute(args)
    return { error: 'No está en la cartera: pásalo al cobrador.' } unless customer

    receivable = customer.receivables.where(status: 'open').find_by('LOWER(folio) = ?', args['folio'].to_s.strip.downcase)
    return { error: "No veo la factura #{args['folio']} en lo que debe: pregúntale el folio tal cual." } unless receivable

    receivable.update!(disputed_at: Time.current) unless test?
    @turn.decide('dispute', "Factura #{receivable.folio}: #{args['motivo']}")
    { ok: true, nota: 'Listo: dile que el área revisa esa factura y que no se la cobraremos mientras tanto.' }
  end

  def amount_text(amount) = amount.present? ? " por #{Receivables::Summary.money(amount)}" : ''
end
