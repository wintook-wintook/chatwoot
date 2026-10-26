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

  # B9 del comprobador. Bloqueante, y un solo hallazgo para todas: la lista es lo que
  # hay que completar. Las demás reglas saltean lo marcado, para no decir lo mismo con
  # peores palabras. Lleva la línea de la primera marca, que es lo que permite
  # señalar el nodo donde falta el dato en vez de dejar el aviso suelto.
  def check(text, findings:)
    marcas = scan(text)
    return if marcas.empty?

    indice = text.to_s.lines.index { |linea| pending?(linea) }
    mensaje = I18n.t('tracking_assistant.findings.pending_marker',
                     locale: ContactTrackings::Assistant::Language.resolve,
                     count: marcas.size, items: marcas.uniq.first(5).join(' · '))
    findings.add(:blocking, :pending_marker, mensaje, line: indice && (indice + 1), wrote: marcas.first)
  end
end
