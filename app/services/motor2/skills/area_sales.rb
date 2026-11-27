# frozen_string_literal: true

# «Atención a clientes» › Comercial (lo usa Motor2::Skills::AreaActions): información solo con lo que
# confirmen las fuentes; cotización, contratar o un vendedor → oportunidad (si la empresa lo eligió) o
# pasarlo al vendedor; demo o visita → agendarla (si eligió agendar y hay con quién) o registrarla
# para que el vendedor la acuerde. Si ya tiene una oportunidad abierta, se le agrega (no se abre otra).
module Motor2::Skills::AreaSales
  CART_INSTEAD = { error: 'Va armando su cuenta: para agregar o quitar usa agregar_a_cuenta / quitar_de_cuenta. No lo registres.' }.freeze
  CART_NOTE = 'Va armando su cuenta: si quiere agregar, quitar o cambiar algo, usa agregar_a_cuenta / quitar_de_cuenta; si ' \
              'pregunta cuánto lleva, ver_cuenta. La cotización formal solo si la pide (cotizar sin partidas: usa su cuenta).'
  # Con «Cotizaciones» prendido la cotización la arma el agente: registrarla dejaba otra oportunidad y «un vendedor te da
  # seguimiento».
  QUOTE_INSTEAD = { error: 'Las cotizaciones las armas tú: llama cotizar con los productos y cantidades (si falta qué o ' \
                           'cuántos, pregúntalo). No la registres.' }.freeze
  SALES_INFO = 'Información comercial: contesta SOLO con lo que confirme buscar_en_fuentes o lo que diga EL NEGOCIO (horario, ' \
               'dirección, formas de pago, políticas); si no lo confirma, dilo y ofrece pasarlo con alguien del equipo.'

  private

  def sales_note
    sales = function.area('sales').to_h
    case now['gestion']
    when nil, 'info' then SALES_INFO
    when 'demo', 'visita' then appointment_note(sales)
    when 'cita' then booking_note(sales)
    when 'cotizacion' then quote_note
    else 'Pidió una gestión comercial: llama registrar_gestion con lo que pidió (qué y cuántos) y dile que su vendedor le da seguimiento.'
    end
  end

  # Con «cotizar» prendido, la arma él (Motor2::Skills::Quote); si no, se registra para el vendedor.
  def quote_note
    return CART_NOTE if @turn.find_skill('quote')&.cart?

    if @turn.find_skill('quote')
      return 'Pidió una cotización: si ya sabes qué productos y cuántos, llama cotizar ya (no le des los precios sueltos ni le ' \
             'preguntes si la quiere; si solo un producto coincide con lo que dijo, es ese); si falta qué o cuántos, pregúntalo ' \
             'en una pregunta (sin buscar en fuentes ni decir que no encontraste nada).'
    end

    'Pidió una gestión comercial: llama registrar_gestion con lo que pidió (qué y cuántos) y dile que su vendedor le da seguimiento.'
  end

  def appointment_note(sales)
    field = now['gestion'] == 'demo' ? 'demo' : 'visit'
    if sales[field] == 'appointment' && appointments_on?
      return "Pidió #{now['gestion']}: agéndala con ver_horarios y agendar_cita (no otra cosa en su lugar)."
    end

    "Pidió #{now['gestion']}: llama registrar_gestion (tipo #{now['gestion']}) y dile que su vendedor lo contacta para acordarla. No la agendes tú."
  end

  # Cita de servicio: la agenda él con los servicios del Catálogo; si la empresa no agenda, se registra para el vendedor.
  def booking_note(sales)
    if sales['booking'] == 'appointment' && appointments_on?
      return 'Quiere una cita de servicio: si no sabes qué servicio(s), pregúntalo; en cuanto lo sepas llama ver_horarios con ' \
             'esos servicios (no pidas confirmación antes) y, cuando elija horario, agendar_cita (si ya tiene cita, mover_cita o ' \
             'cancelar_cita).'
    end

    'Quiere una cita: llama registrar_gestion (tipo cita) con qué servicio y cuándo, y dile que le confirman el horario. No la agendes tú.'
  end

  # Cotización, contratar, vendedor, demo o visita: oportunidad (si la empresa lo eligió) o pasarlo al vendedor.
  def register(args)
    return QUOTE_INSTEAD if args['tipo'].to_s == 'cotizacion' && @turn.find_skill('quote')
    return CART_INSTEAD if %w[contratar otra].include?(args['tipo'].to_s) && @turn.find_skill('quote')&.cart?

    register_sale(args)
  end

  def register_sale(args)
    tipo = args['tipo'].to_s
    detail = args['detalle'].to_s.strip.first(1000)
    return channel("#{tipo}: #{detail}") unless function.area('sales').to_h['quote'] == 'opportunity'

    @acted = true
    return { ok: true, prueba: true, folio: 'PRUEBA-2', nota: 'Dile que su vendedor le da seguimiento.' } if test?

    existing = orchestrator.find_active_ticket(case_class: :commercial)
    return add_to(existing, tipo, detail) if existing

    ticket = new_case("#{tipo.capitalize}: #{detail}".first(200), detail, case_type_for('sales', :commercial), nil)
    trace.event(:caso, "Comercial: #{ticket.title}")
    { ok: true, folio: ticket.try(:folio) || ticket.id, nota: 'Dile que su vendedor le da seguimiento (sin prometer tiempos).' }
  end

  # Ya tenía una oportunidad abierta: se le agrega lo que pidió (no se abre otra).
  def add_to(ticket, tipo, detail)
    Motor2::Delivery.note(@turn.tracking, @turn.conversation, "🤖 Pidió #{tipo}: #{detail}") unless test?
    { ok: true, folio: ticket.try(:folio) || ticket.id, nota: 'Ya tenía una oportunidad abierta: se le agregó.' }
  end
end
