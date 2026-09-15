# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — FRASES DE PRUEBA SACADAS DE UNA RAMA
# ================================================================================
# La descripción de una rama YA ES una lista de situaciones en las palabras del
# cliente —para eso existe: es lo único que el clasificador lee—. Así que las pruebas
# se escriben solas: cada situación es un mensaje que un cliente mandaría.
#
# Lo comparten RouteSelfCheck (una frase por rama, al entregar) y SuggestedTests
# (varias, a pedido): si cada uno cortara distinto, la pantalla diría una cosa y la
# comprobación automática otra.
# ================================================================================

module ContactTrackings::Assistant::ProbePhrases
  MAX_CHARS = 120
  # ⚠ Una situación de una sola palabra no es un mensaje de cliente. La rama soporte
  # del v6.11 empieza "usar, configurar, dar de alta…": probada con "usar" a secas,
  # gpt-4o-mini —el modelo que se usa cuando no hay canal, que en el Asistente es
  # siempre— no eligió ninguna rama 3 de 3 veces, y la pantalla mostraba un cruce que
  # no existía. Con "usar, configurar" eligió soporte 3 de 3 (medido 15/09/2026).
  MIN_WORDS = 3

  module_function

  # Hasta `limit` frases: cada situación de la descripción, sumando las siguientes
  # mientras quede por debajo de MIN_WORDS. Una descripción pendiente no da ninguna.
  def for(route, limit: 1)
    descripcion = route.description.to_s
    return [] if ContactTrackings::Assistant::PendingMarkers.pending?(descripcion)

    group(descripcion.split(/[,;]/).map(&:strip).compact_blank)
      .map { |partes| partes.join(', ').truncate(MAX_CHARS) }
      .first(limit)
  end

  # [["usar", "configurar"], ["dar de alta un cliente"]]: tandas de al menos
  # MIN_WORDS palabras. La última va aunque quede corta: es lo que hay.
  def group(situaciones)
    situaciones.each_with_object([[]]) do |situacion, tandas|
      tandas << [] if tandas.last.join(' ').split.size >= MIN_WORDS
      tandas.last << situacion
    end.reject(&:empty?)
  end
end
