# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — EL CLASIFICADOR REAL, SOBRE UN BORRADOR
# ================================================================================
# A qué rama mandaría el motor un mensaje, con un Entrenamiento que todavía no es un
# agente. Es BranchClassifierService —el mismo que corre en producción— con objetos
# reales sin persistir: si se reimplementara acá, las pruebas dirían algo distinto de
# lo que va a pasar.
#
# ⚠ Ante un error de la llamada, el clasificador del motor NO avisa: devuelve la rama
# por defecto (es fail-soft a propósito, en producción). Por eso las pruebas corren en
# serie: en paralelo, un pool de conexiones agotado se leería como "cayó en la rama
# por defecto" y la prueba fallaría por algo que no es el ruteo.
# ================================================================================

class ContactTrackings::Assistant::DraftClassifier
  def initialize(account, draft:, inbox: nil)
    @account = account
    @draft = draft.to_s
    @inbox = inbox
    @map = ContactTrackings::RouteMap.parse(@draft)
  end

  attr_reader :map

  # La rama elegida (RouteMap::Route) o nil.
  def classify(content)
    message = Message.new(account: @account, content: content, message_type: :incoming)
    ContactTrackings::BranchClassifierService.new(tracking, message, @map).classify
  rescue StandardError => e
    Rails.logger.warn "[Asistente] no se pudo clasificar: #{e.message}"
    nil
  end

  private

  def tracking
    @tracking ||= ContactTracking.new(inbox: @inbox, complementary_prompt: @draft)
  end
end
