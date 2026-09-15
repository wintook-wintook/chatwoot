# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — DATOS POR COMPLETAR (fase C de PROMPT STUDIO)
# ================================================================================
# <PENDIENTE: qué falta> es la marca que pone el Asistente en vez de inventar un dato
# que todavía no le dieron. Con el Entrenamiento construyéndose a la vista, un
# borrador tiene varias mientras dura la entrevista.
#
# ⚠ Hasta el 15/09/2026 ninguna regla las conocía: en una fuente salían como "fuente
# que el motor no reconoce" (falso: falta elegirla), tres descripciones marcadas
# salían como "descripciones repetidas", y en la prosa no salía nada — se podía
# guardar, y el agente le leía "<PENDIENTE: horario>" al cliente tal cual.
#
# Vale también en inglés: la marca es sintaxis, no prosa.
# ================================================================================

module ContactTrackings::Assistant::PendingMarkers
  RE = /<\s*(?:PENDIENTE|PENDING)\b[^>]*>/i

  module_function

  def pending?(value)
    value.to_s.match?(RE)
  end

  def scan(text)
    text.to_s.scan(RE)
  end
end
