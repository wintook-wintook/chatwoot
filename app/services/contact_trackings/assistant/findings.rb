# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — HALLAZGOS DEL COMPROBADOR
# ================================================================================
# Colector de lo que encuentra ValidatorService, agrupado por severidad.
#
# POR QUÉ ES UN OBJETO Y NO UN ARRAY SUELTO:
#   El contrato de un hallazgo —DÓNDE, QUÉ pasa, POR QUÉ, y QUÉ SE ESCRIBIÓ— no es
#   una preferencia de redacción: es lo que decide si el aviso repara el
#   Entrenamiento o no. Medido el 08/09/2026 con el mismo texto roto y el mismo
#   modelo: con un veredicto pelado ("no hay ninguna línea @ruta") se reparó 1 de 3
#   veces; nombrando el carácter que faltaba y su línea, 3 de 3.
#   Teniendo la firma en un solo lugar, agregar una comprobación nueva obliga a
#   pasar por acá y a decidir qué se le muestra a quien tiene que corregir.
#
# SEVERIDADES:
#   blocking  — si falla, esa parte del agente NO EXISTE. Impide guardar.
#   degrading — funciona, pero mal. Avisa y deja guardar.
#   cosmetic  — mejora la redacción, no rompe nada.
# ================================================================================

class ContactTrackings::Assistant::Findings
  SEVERITIES = %i[blocking degrading cosmetic].freeze

  def initialize
    @items = []
  end

  # `wrote` es lo que la persona (o el modelo) escribió de verdad. Sin eso, el
  # lector mira su propio texto, no ve el problema, y descarta el aviso.
  def add(severity, code, message, line: nil, wrote: nil)
    @items << { severity: severity, code: code, message: message, line: line, wrote: wrote }.compact
  end

  def code?(code)
    @items.any? { |item| item[:code] == code }
  end

  # La severidad no viaja al consumidor: ya está en la llave que lo agrupa.
  def of(severity)
    @items.select { |item| item[:severity] == severity }.map { |item| item.except(:severity) }
  end
end
