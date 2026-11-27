# frozen_string_literal: true

# ================================================================================
# proyecto@crear_agente_conversando §15 — PROBAR FUENTES (P2: hojas exactas y ERP)
# ================================================================================
# Lo que no se busca por parecido, probado con las mismas piezas que usa el motor:
#
#   {{hoja_buscar: Precios | Producto=? | Precio}}   SheetLookup con la FRASE como texto
#                                                    (los «?» salen de ella). Sin IA.
#   {{hoja:Ventas}} en modo datos                    SheetQueryService: la IA traduce la
#                                                    pregunta y Ruby calcula exacto.
#   {{consulta:sae/saldo(rfc=?)}}                    con «?»: la IA llena los parámetros
#                                                    (AskedParams) y corre (AskedRun);
#                                                    sin «?»: el render de siempre.
#
# La pantalla avisa cuáles gastan una llamada de IA (`uses_ai` en la lista). El RFC del
# contacto, que en una conversación sale de su ficha, aquí se puede escribir de prueba.
# ================================================================================

class ContactTrackings::Assistant::SourceProbeExact
  Lookup = ContactTrackings::SheetLookup
  Renderer = ExternalDb::ConsultaDirectiveRenderer
  MAX_ROWS = KnowledgeBaseResponseService::MAX_LOOKUP_ROWS
  # En una conversación, el RFC sale de la ficha del contacto (custom_attributes erp_rfc).
  TestContact = Struct.new(:custom_attributes)

  def initialize(account, inbox: nil, rfc: nil)
    @account = account
    @inbox = inbox
    @rfc = rfc.to_s.strip.presence
  end

  # Con lo que trae la frase, qué filas encuentra y qué regresaría. Sin IA.
  def sheet_lookup(inner, frase)
    return { kind: 'sheet_lookup', error: 'google_disabled' } unless google?

    spec = Lookup.parse(inner)
    return { kind: 'sheet_lookup', error: 'invalid_directive' } if spec.nil?

    lookup_payload(spec, Lookup.new(@account, spec, text: frase).call)
  end

  # La hoja en modo datos responde un resultado ya calculado (o nada).
  def sheet_data(source, frase)
    return { kind: 'sheet_data', error: 'google_disabled' } unless google?
    return { kind: 'sheet_data', error: 'source_missing' } if source.nil?

    respuesta = SheetQueryService.new(source, frase, @account).perform
    { kind: 'sheet_data', status: respuesta.present? ? 'ok' : 'no_answer', answer: respuesta }
  end

  def erp(raw, frase)
    directiva = Renderer.parse(raw).first
    return { kind: 'erp', error: 'invalid_directive' } if directiva.nil?

    consulta = renderer.resolve(directiva)
    return { kind: 'erp', error: 'query_missing' } if consulta.nil?

    directiva.asks? ? asked(directiva, consulta, frase) : { kind: 'erp', status: 'ok', rendered: renderer.render(raw).strip }
  rescue StandardError => e
    { kind: 'erp', error: 'failed', detail: e.message.truncate(200) }
  end

  private

  def lookup_payload(spec, resultado)
    base = { kind: 'sheet_lookup', status: resultado.status.to_s, sheet: spec.sheet, returns: spec.returns,
             criteria: resultado.criteria, asked: resultado.asked, missing: resultado.missing }
    return base.compact unless resultado.ok?

    filas = Lookup.describe(spec, resultado.rows)
    base.merge(found: resultado.found, rows: filas.first(MAX_ROWS), more: [filas.size - MAX_ROWS, 0].max).compact
  end

  # Como el motor: la IA dice si la frase pide esta consulta y con qué valores.
  def asked(directiva, consulta, frase)
    lleno = ExternalDb::AskedParams.new(query: consulta, asked: directiva.asked, question: frase, inbox: @inbox).call
    return { kind: 'erp', status: 'not_asked' } unless lleno && lleno[:use]

    parametros = renderer.params_for(directiva, consulta, lleno[:params])
    datos = ExternalDb::AskedRun.new(consulta, parametros).call
    { kind: 'erp', status: datos[:rows].any? ? 'ok' : 'no_rows', params: parametros, columns: datos[:columns],
      rows: datos[:rows].first(MAX_ROWS), partial: datos[:partial] }
  end

  def renderer
    contacto = TestContact.new({ Renderer::CONTACT_RFC_ATTR => @rfc }) if @rfc
    @renderer ||= Renderer.new(account: @account, contact: contacto, inbox: @inbox)
  end

  def google? = @account.feature_enabled?('google_calendar')
end
