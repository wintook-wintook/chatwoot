# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — LO QUE EL MOTOR VA A LEER
# ================================================================================
# Traduce las ramas que parseó RouteMap a la forma que muestra la pantalla:
# nombre, etiqueta, descripción, fuente ya resuelta y escalamiento.
#
# Es una pieza aparte del comprobador porque responde otra pregunta. El comprobador
# dice qué está MAL; esto dice qué va a PASAR, incluso cuando todo está bien — que
# es lo que hace distinta a esta pantalla de un editor de texto cualquiera: antes de
# guardar se ve, en las palabras del motor, qué ramas reconoció y en qué fuente va a
# buscar cada una.
# ================================================================================

class ContactTrackings::Assistant::RouteReport
  def initialize(map)
    @map = map
  end

  def call
    @map.routes.map { |route| describe(route) }
  end

  private

  def describe(route)
    # `detect` es el mismo que usa el motor al atender un turno: la fuente que sale
    # acá es exactamente la que se va a consultar en producción.
    detected = route.directive.present? ? KnowledgeBase::Directives.detect(route.directive) : nil

    {
      name: route.name,
      tag: route.hashtag,
      description: route.description,
      directive: route.directive,
      mode: detected&.dig(:mode),
      source_name: detected&.dig(:source_name),
      escalation: route.escalation
    }
  end
end
