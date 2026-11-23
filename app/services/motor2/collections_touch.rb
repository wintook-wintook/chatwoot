# frozen_string_literal: true

# «Cobranza» — el mensaje del toque (cuando se puede escribir libre: correo, o WhatsApp con la ventana abierta). Lo arma el
# código, no la IA: el saludo según la etapa, el «Resumen de saldo pendiente» con los montos de la cartera, los datos para
# pagar y el cierre. nil si el seguimiento no es de cobranza (Motor2::AttemptHook sigue con los demás).
module Motor2::CollectionsTouch
  OPENING = {
    'preventive' => 'te recordamos que tienes facturas por vencer:',
    'due' => 'te escribimos para recordarte que tienes un saldo vencido:',
    'overdue_30' => 'seguimos pendientes del pago de tu cuenta:',
    'overdue_60' => 'seguimos pendientes del pago de tu cuenta, que ya tiene más de 30 días vencida:',
    'overdue_plus' => 'seguimos pendientes del pago de tu cuenta, que ya tiene más de 60 días vencida:'
  }.freeze

  module_function

  def text(tracking)
    customer_id = tracking.motor2_state.to_h.dig('collections', 'customer_id')
    customer = customer_id && ReceivableCustomer.find_by(id: customer_id, account_id: tracking.account_id)
    return nil unless customer

    summary = Receivables::Summary.new(customer)
    return nil if summary.invoices.empty?

    function = Motor2::Config.for(tracking).function
    [opening(tracking.contact, summary.stage), summary.text, payment(function), closing(summary.stage)].compact.join("\n\n")
  end

  def opening(contact, stage)
    name = contact&.name.to_s.split.first
    hello = name.present? && !name.match?(/\A[+\d]/) ? "Hola #{name}," : 'Hola,'
    "#{hello} #{OPENING.fetch(stage, OPENING['due'])}"
  end

  def payment(function)
    info = function.respond_to?(:payment_info) ? function.payment_info : ''
    info.present? ? "Para pagar:\n#{info}" : nil
  end

  def closing(stage)
    return 'Si ya pagaste, mándanos tu comprobante por aquí. Cualquier duda, aquí estamos.' if stage == 'preventive'

    'Si ya pagaste, mándanos tu comprobante por aquí. ¿En qué fecha podrías realizar tu pago?'
  end
end
