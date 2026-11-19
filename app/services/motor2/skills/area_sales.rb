# frozen_string_literal: true

# «Atención a clientes» › Comercial (lo usa Motor2::Skills::AreaActions): información solo con lo que
# confirmen las fuentes; cotización, contratar o un vendedor → oportunidad (si la empresa lo eligió) o
# pasarlo al vendedor; demo o visita → agendarla (si eligió agendar y hay con quién) o registrarla
# para que el vendedor la acuerde. Si ya tiene una oportunidad abierta, se le agrega (no se abre otra).
module Motor2::Skills::AreaSales
  SALES_INFO = 'Información comercial: contesta SOLO con lo que confirme buscar_en_fuentes; si no lo confirma, dilo y ofrece ' \
               'pasarlo con un vendedor.'

  private

  def sales_note
    sales = function.area('sales').to_h
    case now['gestion']
    when nil, 'info' then SALES_INFO
    when 'demo', 'visita' then appointment_note(sales)
    else 'Pidió una gestión comercial: llama registrar_gestion con lo que pidió (qué y cuántos) y dile que su vendedor le da seguimiento.'
    end
  end

  def appointment_note(sales)
    field = now['gestion'] == 'demo' ? 'demo' : 'visit'
    if sales[field] == 'appointment' && appointments_on?
      return "Pidió #{now['gestion']}: agéndala con ver_horarios y agendar_cita (no otra cosa en su lugar)."
    end

    "Pidió #{now['gestion']}: llama registrar_gestion (tipo #{now['gestion']}) y dile que su vendedor lo contacta para acordarla. No la agendes tú."
  end

  # Cotización, contratar, vendedor, demo o visita: oportunidad (si la empresa lo eligió) o pasarlo al vendedor.
  def register(args)
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
