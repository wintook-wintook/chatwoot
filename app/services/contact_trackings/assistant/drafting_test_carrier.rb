# frozen_string_literal: true

# ================================================================================
# proyecto@crear_agente_conversando — FD: EL AGENTE NACE PROBADO
# ================================================================================
# Plan: docs/creacion_conversacional_agentes_plan.md §7, punto 5. Las frases que el
# chat de creación probó con el clasificador real (proposal['pruebas'] de la
# conversación) pasan a la pila del agente al guardarlo.
#
# La ruta esperada se queda solo si esa ruta existe en el Entrenamiento guardado (el
# redactor pudo nombrarla distinto); si no, la prueba queda como propia y la prueba en
# seco dirá a dónde cae. Ninguna repetida y nunca más del tope de la pila.
# ================================================================================

class ContactTrackings::Assistant::DraftingTestCarrier
  def initialize(session, template)
    @session = session
    @template = template
  end

  def call
    pruebas.each { |prueba| carry(prueba) }
  rescue StandardError => e
    Rails.logger.warn "[Asistente] no se pasaron las pruebas de la conversación a la pila: #{e.message}"
  end

  private

  def pruebas = Array(@session.proposal.to_h['pruebas'])

  def carry(prueba)
    frase = prueba['frase'].to_s.strip
    return if frase.blank? || existing.include?(frase.downcase) || full?

    ruta = prueba['cae_en'].to_s.downcase
    ContactTrackings::Assistant::TestCases.add_own(@session.account, @template, frase,
                                                   expected_route: (ruta if routes.include?(ruta)))
    existing << frase.downcase
  end

  def existing
    @existing ||= @template.test_cases.pluck(:message).map(&:downcase)
  end

  def full? = @template.test_cases.count >= TrackingTestCase::MAX_PER_TEMPLATE

  def routes
    @routes ||= ContactTrackings::RouteMap.parse(@template.complementary_prompt.to_s).routes.map { |r| r.name.downcase }
  end
end
