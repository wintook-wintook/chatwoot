# frozen_string_literal: true

# ================================================================================
# feat/ficha_agente_ia — LAS FRASES CON QUE SE PRUEBA EL AGENTE ANTES DE CREARLO
# ================================================================================
# Idea 1 de «más facilidad» (09/11/2026). Las descripciones de las rutas generadas salen
# de columnas y temas; probarlas con su propia descripción no diría nada. Por eso las
# frases salen del CONTENIDO de cada recurso, como las escribiría un cliente, SIN IA:
#
#   hoja «Precios» (Servicio=? → Precio)   «¿Cuál es el precio de Plataforma?»
#   grupo PATITAS (temas)                  «Quiero saber sobre política cancelación»
#   agenda                                 «Quiero agendar una cita»
#   ticket «Renta Unidades»                «Necesito renta unidades»
#
# Más hasta REAL_LIMIT frases reales de los clientes de la cuenta (InventoryService,
# enmascaradas), sin ruta esperada: dicen a dónde caería lo que de verdad escriben.
# ================================================================================

class ContactTrackings::Ficha::TestPhrases
  PER_ROUTE = 2
  REAL_LIMIT = 6
  KEY_RE = /\{\{\s*hoja_buscar:\s*[^|]+\|\s*([^=|]+?)\s*=\s*\?\s*\|\s*([^}]+)\}\}/

  # from_description: un agente escrito a mano: sus descripciones ya están en palabras del
  # cliente (y dos rutas pueden usar el mismo recurso para cosas distintas, p. ej. agendar
  # consulta y vacunación): se prueba con ellas; el recurso solo si la ruta no describe nada.
  def initialize(account, routes:, offers:, inbox: nil, from_description: false)
    @from_description = from_description
    @account = account
    @routes = routes
    @offers = offers.index_by { |o| o[:key].to_s }
    @inbox = inbox
  end

  # { per_route: [{ route:, key:, label:, phrases: [..] }], real: [..] }
  def call
    { per_route: @routes.filter_map { |ruta| route_entry(ruta) }, real: real_phrases }
  end

  private

  def route_entry(ruta)
    oferta = @offers[ruta[:key].to_s]
    frases = described_phrases(ruta) if @from_description || oferta.nil?
    frases = phrases_for(oferta) if frases.blank? && oferta
    frases = frases.map { |f| f.to_s.squish }.compact_blank.uniq.first(PER_ROUTE)
    frases.any? ? { route: ruta[:name], key: ruta[:key], label: ruta[:label], phrases: frases } : nil
  end

  # Frases fijas por tipo (%<nombre>s = el recurso en minúsculas, %<tema>s = su tema).
  FIXED = {
    'calendar' => ['Quiero agendar una cita', '¿Tienen disponibilidad para mañana?'],
    'case_type' => ['Necesito %<nombre>s', 'Quiero levantar una solicitud de %<nombre>s'],
    'erp' => ['Quiero consultar %<tema>s'],
    'forum' => ['Tengo un problema y no sé cómo resolverlo, ¿me ayudas?'],
    'discourse' => ['Tengo un problema y no sé cómo resolverlo, ¿me ayudas?'],
    'contpaq' => ['Me sale un error en CONTPAQi, ¿cómo lo soluciono?']
  }.freeze
  BY_TOPIC = %w[canned doc articles].freeze

  def phrases_for(oferta)
    return sheet_phrases(oferta) if oferta[:kind] == 'sheet'
    return topic_phrases(oferta) if BY_TOPIC.include?(oferta[:kind])

    Array(FIXED[oferta[:kind]]).map do |plantilla|
      format(plantilla, nombre: oferta[:name].to_s.downcase, tema: oferta[:topic].to_s.downcase)
    end
  end

  # Una ruta escrita a mano que no usa ningún recurso: sus propias situaciones
  # (ProbePhrases, lo mismo que la comprobación del Asistente).
  def described_phrases(ruta)
    return [] if ruta[:description].blank?

    ContactTrackings::Assistant::ProbePhrases.for(Struct.new(:description).new(ruta[:description]), limit: PER_ROUTE)
  end

  def topic_phrases(oferta)
    oferta[:topic].to_s.split(',').map(&:strip).compact_blank.first(PER_ROUTE).map { |t| "Quiero saber sobre #{t}" }
  end

  # «¿Cuál es el precio de Plataforma?» con la columna por la que busca y la que regresa.
  def sheet_phrases(oferta)
    clave, regresa = oferta[:directive].to_s.match(KEY_RE)&.captures
    valores = sheet_values(oferta, clave)
    return ["Quiero información de #{oferta[:name]}"] if valores.empty?

    columna = regresa.to_s.split(',').first.to_s.strip.downcase.presence || 'información'
    valores.first(PER_ROUTE).map { |v| "¿Cuál es el #{columna} de #{v}?" }
  end

  def sheet_values(oferta, clave)
    hoja = @account.knowledge_sources.find_by(id: oferta[:key].to_s.split(':').last)
    return [] if hoja.nil? || clave.blank?

    hoja.google_sheet_rows.order(:row_index).limit(3).map(&:data).filter_map { |d| d[clave.strip].to_s.strip.presence }.uniq
  end

  def real_phrases
    ContactTrackings::Assistant::InventoryService.new(@account, inbox: @inbox).call[:customer_phrases].to_a.first(REAL_LIMIT)
  rescue StandardError
    []
  end
end
