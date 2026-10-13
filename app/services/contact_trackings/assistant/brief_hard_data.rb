# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — LO QUE FALTA DEL ENCARGO EN LO ESCRITO (P8, Paso 3.3)
# ================================================================================
# Sin IA. Para la herramienta `revisar_encargo`: el Asistente lo usa ANTES de entregar
# un agente creado desde un encargo, y pone lo que falte en su lugar.
#
#   faltan_reglas  lo que BriefCoverage agregaría (reglas, prohibiciones, tono, datos a
#                  pedir): la misma medida, pero antes de entregar y no pegado al final.
#   faltan_datos   los DATOS DUROS del encargo (teléfonos, números largos, montos,
#                  correos, enlaces) que no están ni en lo escrito ni en el Contexto que
#                  se propone para la Definición.
#
# POR QUÉ DEL TEXTO ORIGINAL Y NO DE LA FICHA: medido el 13/10/2026 (T1 del P8, encargo
# #1131), la LECTURA del encargo ya perdió el número de la Línea de la Vida: la ficha
# dice «comparte Línea de la Vida» sin el 800 911 2000. Revisar contra la ficha nunca
# lo habría encontrado.
# ================================================================================

class ContactTrackings::Assistant::BriefHardData
  PATTERNS = [
    /(?<!\d)\d{2,4}(?:[ .-]?\d{2,4}){2,4}(?!\d)/, # 800 911 2000 · 33 1234 5678
    /\$\s?\d[\d,.]*/,                             # $600 · $1,000
    /[\w.+-]+@[\w-]+\.[\w.]+/,                    # correo
    %r{https?://[^\s)>\]]+}                       # enlace
  ].freeze
  MIN_DIGITS = 3
  MAX_ITEMS = 15

  def initialize(brief, inventory: {})
    @brief = brief
    @inventory = inventory
  end

  def check(texto)
    reglas = ContactTrackings::Assistant::BriefCoverage
             .new(texto, ficha: @brief.digest.to_h['ficha'], answers: @brief.answers).call[:added]
             .map { |a| "#{a['section']}: #{a['text']}" }
    datos = missing_data("#{texto}\n#{ai_context}")
    { faltan_reglas: reglas.first(MAX_ITEMS), faltan_datos: datos.first(MAX_ITEMS), completo: reglas.empty? && datos.empty? }
  end

  # Cada dato duro del encargo, con la línea donde aparece (para que el modelo sepa
  # a qué tema pertenece).
  def hard_data
    @hard_data ||= begin
      datos = @brief.content.to_s.each_line.flat_map { |linea| data_in(linea) }
      datos.select { |d| key(d[:dato]).present? }.uniq { |d| key(d[:dato]) }
    end
  end

  def data_in(linea)
    PATTERNS.flat_map { |re| linea.scan(re) }
            .map { |dato| { dato: dato.strip.sub(/[.,;:]+\z/, ''), linea: linea.strip.truncate(160) } }
  end

  private

  def missing_data(escrito)
    compacto = escrito.downcase.gsub(/[\s.,-]/, '')
    hard_data.reject { |d| compacto.include?(key(d[:dato])) }
  end

  # Correos y enlaces tal cual; números por sus dígitos («800-911-2000» = «800 911 2000»).
  def key(dato)
    return dato.downcase.gsub(/[\s.,-]/, '') if dato.match?(/@|http/)

    digitos = dato.gsub(/\D/, '')
    digitos.length >= MIN_DIGITS ? digitos : nil
  end

  # Lo que la redacción propone como Contexto de la Definición (BriefComposer): lo que
  # está ahí también le llega al agente.
  def ai_context
    propuesta = ContactTrackings::Assistant::BriefComposer.new(@brief, answers: @brief.answers, inventory: @inventory).call[:proposal]
    propuesta.to_h.with_indifferent_access[:ai_context].to_s
  rescue StandardError => e
    Rails.logger.warn "[Asistente/herramientas] no se pudo leer el Contexto propuesto: #{e.message}"
    ''
  end
end
