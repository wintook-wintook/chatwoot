# frozen_string_literal: true

# Motor 2.0 — «Atención a clientes» › Comercial: pidió una cotización y contestó con precios sueltos sin armarla
# (Motor2::Skills::Quote#cotizar). Se le pide una vez que la arme (o que pregunte qué o cuántos, si falta) y se manda
# lo que conteste. Lo corre Motor2::QuestionGuard#guard_turn; lo incluye Motor2::Runner.
module Motor2::QuoteCheck
  NO_QUOTE = 'Pidió una cotización y no la armaste. Si ya sabes qué servicios o productos y cuántos, llama cotizar ahora y ' \
             'contesta con lo que regrese (folio y total); si falta qué o cuántos, pregúntalo en una pregunta.'

  QUOTE_TOOLS = %w[cotizar agregar_a_cuenta quitar_de_cuenta ver_cuenta].freeze # con «su cuenta», agregar también cuenta

  private

  def ensure_quote(messages, text)
    return text unless quote_pending?

    @trace.event(:revision, 'pidió cotización y no la armó')
    messages << { role: 'assistant', content: text } << { role: 'system', content: NO_QUOTE }
    again = clean(run(messages))
    again.present? && !unsourced?(again) ? again : text
  end

  def quote_pending?
    return false unless @mode == :reply && @decision.nil? && find_skill('quote')

    asked_quote? && @trace.tools.none? { |t| QUOTE_TOOLS.include?(t['name']) }
  end

  def asked_quote?
    areas = find_skill('areas')
    areas.present? && areas.area_key == 'sales' && areas.now['gestion'] == 'cotizacion'
  end
end
